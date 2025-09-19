	# Fast Base64 encoding for x86_64 processors with AVX2 support.
	# Copyright (C) 2025 Du Yijie.
	#
	# This library is free software; you can redistribute it and/or
	# modify it under the terms of the GNU Lesser General Public
	# License as published by the Free Software Foundation; either
	# version 2.1 of the License, or (at your option) any later version.
	#
	# This library is distributed in the hope that it will be useful,
	# but WITHOUT ANY WARRANTY; without even the implied warranty of
	# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	# Lesser General Public License for more details.
	#
	# You should have received a copy of the GNU Lesser General Public
	# License along with this library; if not, see
	# <https://www.gnu.org/licenses/>.
	.intel_syntax	noprefix

	# void base64_encode_haswell(const char *restrict in, size_t inlen,
	#                            char *restrict out, size_t outlen);
	.globl		base64_encode_haswell
	.type		base64_encode_haswell, @function
	.text
	.p2align	6, 0x90
base64_encode_haswell:
	.cfi_startproc
	.cfi_def_cfa_register	rsp
	.cfi_def_cfa_offset	8
	push		rbx
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		rbx, 0
	push		rbp
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		rbp, 0
	push		r12
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		r12, 0
	sub		rsp, 32
	.cfi_adjust_cfa_offset	32

	prefetchnta	[rdi]
	prefetchnta	[rdx]

	vmovdqa		ymm6, [rip+loadmask]
	vbroadcasti128	ymm7, [rip+shufflemask]
	vpbroadcastd	ymm8, [rip+unit02_mask]
	vpbroadcastd	ymm9, [rip+unit13_mask]
	vpbroadcastd	ymm10, [rip+unit02_mulhi]
	vpbroadcastd	ymm11, [rip+unit13_mullo]
	vpbroadcastw	ymm12, [rip+satsub]
	vpbroadcastw	ymm13, [rip+capitals]
	vpbroadcastw	ymm14, [rip+cap_index]
	vbroadcasti128	ymm15, [rip+offsets]

	cmp		rsi, 24
	jb		.Llast
	jmp		.Lhot
	.p2align	6, 0x90

	# Encode a block of 24 bytes to base64.
	# ymm6: load mask
	# ymm7: shuffle mask
	# ymm8-ymm11: masks and shifts for splitting
	# ymm12-ymm15: tables for converting indices to Base64
	# Result in ymm0. Clobbers ymm1-ymm5.
.macro	encode_block	inptr
	# load and process data into 3 byte units
	vpmaskmovd	ymm0, ymm6, [\inptr-4]
	vpshufb		ymm0, ymm0, ymm7
	# 11112222 22333333 00000011 11112222

	# process 3 byte units into base64 units
	vpand		ymm1, ymm0, ymm8
	vpand		ymm2, ymm0, ymm9
	vpmulhuw	ymm1, ymm1, ymm10
	vpmullw		ymm2, ymm2, ymm11
	vpor		ymm0, ymm1, ymm2

	# convert into the Base64 character set
	vpsubusb	ymm1, ymm0, ymm12
	vpcmpgtb	ymm2, ymm13, ymm0
	vpand		ymm2, ymm2, ymm14
	vpor		ymm1, ymm1, ymm2
	vpshufb		ymm1, ymm15, ymm1
	vpaddb		ymm0, ymm0, ymm1
	# final encoded form of 24 bytes in ymm0
.endm

# LLVM-MCA-BEGIN hot loop
.Lhot:
	prefetchnta	[rdi+24]
	prefetchnta	[rdx+32]

	encode_block	rdi
	add		rdi, 24
	sub		rsi, 24

	# check if the full vector can be copied into output
	cmp		rcx, 32
	jb		.Ltruncate_output
	# copy
	vmovdqu		[rdx], ymm0
	add		rdx, 32
	sub		rcx, 32
	cmp		rsi, 24
	jb		.Llast
	jmp		.Lhot
# LLVM-MCA-END hot loop

	.p2align	3, 0x90
	# not enough bytes
.Ltruncate_output:
	vmovdqu		[rsp], ymm0
	mov		rdi, rdx
	mov		rsi, rsp
	mov		rdx, rcx
	call		memcpy@PLT
	jmp		.Lcleanup

	.p2align	3, 0x90
	# less than 12 bytes remaining
.Llast:
	# save out -> rbx, inlen -> rbp, outlen -> r12
	# (using esi and ebp as inlen < 24 < UINT_MAX)
	mov		rbx, rdx
	mov		ebp, esi
	mov		r12, rcx
	# shortcut for when zero bytes left
	test		esi, esi
	jz		.Lzero_terminate

	# clear buffer for final input at [rsp]
	vpxor		ymm0, ymm0, ymm0
	vmovdqu		[rsp], ymm0
	# copy final data to buffer
	mov		edx, esi
	mov		rsi, rdi
	mov		rdi, rsp
	call		memcpy@PLT

	encode_block	rsp
	vmovdqu		[rsp], ymm0

	# full_units (rax) = inlen / 3
	imul		eax, ebp, 0xAAAB
	shr		eax, 17
	# remainder (rdx) = inlen % 3
	mov		edx, ebp
	lea		ecx, [rax+rax*2]
	sub		edx, ecx

	# pad data
	shl		eax, 2
	test		edx, edx
	jz		.Lcomplete_last
	mov		esi, [rsp+rax]
	lea		rdi, [rip+padding_table]
	and		esi, [rdi+rdx*8+4]
	or		esi, [rdi+rdx*8]
	mov		[rsp+rax], esi
	add		eax, 4

	# rax = number of bytes in buffer, rbx = out, r12 = outlen
.Lcomplete_last:
	# rbp = number of bytes to write
	mov		ebp, eax
	# no buffer overflows, please
	cmp		rax, r12
	cmova		rbp, r12
	# copy
	mov		rdi, rbx
	mov		rsi, rsp
	mov		edx, ebp
	call		memcpy@PLT
	# update out and outlen
	add		rbx, rbp
	sub		r12, rbp
	# ensure rbx <- out and r12 <- outlen here
.Lzero_terminate:
	test		r12, r12
	jz		.Lcleanup
	mov		byte ptr [rbx], 0
.Lcleanup:
	add		rsp, 32
	.cfi_adjust_cfa_offset	-32
	pop		r12
	.cfi_restore		r12
	.cfi_adjust_cfa_offset	-8
	pop		rbp
	.cfi_restore		rbp
	.cfi_adjust_cfa_offset	-8
	pop		rbx
	.cfi_restore		rbx
	.cfi_adjust_cfa_offset	-8
	vzeroupper
	ret
	.cfi_endproc
	.size		base64_encode_haswell, .-base64_encode_haswell


	# void base64url_encode_haswell(const char *restrict in, size_t inlen,
	#                               char *restrict out, size_t outlen);
	.globl		base64url_encode_haswell
	.type		base64url_encode_haswell, @function
	.text
	.p2align	6, 0x90
base64url_encode_haswell:
	.cfi_startproc
	.cfi_def_cfa_register	rsp
	.cfi_def_cfa_offset	8
	push		rbx
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		rbx, 0
	push		rbp
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		rbp, 0
	push		r12
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		r12, 0
	sub		rsp, 32
	.cfi_adjust_cfa_offset	32

	vmovdqa		ymm6, [rip+loadmask]
	vbroadcasti128	ymm7, [rip+shufflemask]
	vpbroadcastd	ymm8, [rip+unit02_mask]
	vpbroadcastd	ymm9, [rip+unit13_mask]
	vpbroadcastd	ymm10, [rip+unit02_mulhi]
	vpbroadcastd	ymm11, [rip+unit13_mullo]
	vpbroadcastw	ymm12, [rip+satsub]
	vpbroadcastw	ymm13, [rip+capitals]
	vpbroadcastw	ymm14, [rip+cap_index]
	vbroadcasti128	ymm15, [rip+offsets_url]

	cmp		rsi, 24
	jb		.Llast
	jmp		.Lhot
	.cfi_endproc
	.size		base64url_encode_haswell, .-base64url_encode_haswell


	.section	.rodata, "a", @progbits
	.p2align	6, 0x0
loadmask:
	.zero		4
	.fill		24, 1, 0xff
	.zero		4
shufflemask:
	# 11112222 22333333 00000011 11112222
	.long		0x05060405, 0x08090708, 0x0b0c0a0b, 0x0e0f0d0e
	.long		0x01020001, 0x04050304, 0x07080607, 0x090a0809

	.p2align	6, 0x0
unit02_mask:
	.long		0x0fc0fc00
unit13_mask:
	.long		0x003f03f0
unit02_mulhi:
	.long		0x04000040
unit13_mullo:
	.long		0x01000010
	# From <https://doi.org/10.1145/3132709>:
	#
	# > Input reduction for encoding
	# > | 6-bit value | reduced | offset |
	# > |-------------|---------|--------|
	# > | 0..25       |      13 |     65 |
	# > | 26..51      |       0 |     71 |
	# > | 52..61      |   1..10 |     -4 |
	# > | 62          |      11 |   -19* |
	# > | 63          |      12 |   -16* |
	#
	# * Offsets are different for base64url.
satsub:
	.fill		4, 1, 51
capitals:
	.fill		4, 1, 26
cap_index:
	.fill		4, 1, 13
	.p2align	4, 0x0
offsets:
	.byte		71, -4, -4, -4, -4, -4, -4, -4
	.byte		-4, -4, -4, -19, -16, 65, 0, 0
offsets_url:
	.byte		71, -4, -4, -4, -4, -4, -4, -4
	.byte		-4, -4, -4, -17, 32, 65, 0, 0

	.p2align	6, 0x0
	# struct padding_table_entry {
	#	uint32_t pad;
	#	uint32_t mask;
	# };
padding_table:
	.long		0
	.long		0xffffffff
	.ascii		"\0\0=="
	.long		0x0000ffff
	.ascii		"\0\0\0="
	.long		0x00ffffff
	.long		0
	.long		0xffffffff
