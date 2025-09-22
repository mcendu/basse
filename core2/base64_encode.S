	# Fast Base64 encoding for x86_64 processors with SSSE3 support.
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
	# Based on techniques from <https://doi.org/10.1145/3132709>.

	# void base64_encode_core2 (const char *restrict in, size_t inlen,
	#                           char *restrict out, size_t outlen);
	.globl		base64_encode_core2
	.type		base64_encode_core2, @function
	.text
	.p2align	6, 0x90
base64_encode_core2:
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
	push		r13
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		r13, 0
	# align the stack frame to 16-byte boundary (see x86_64 psABI)
	sub		rsp, 24
	.cfi_adjust_cfa_offset	24

	# save in -> r13, inlen -> rbp, out -> rbx, outlen -> r12
	# unlike in AVX2 and AVX512 where masked loads are available,
	# these need to be saved early on because of a potential
	# function call in the loop body (see below)
	mov		r13, rdi
	mov		rbp, rsi
	mov		rbx, rdx
	mov		r12, rcx

	prefetchnta	[r13]
	prefetchnta	[rbx]

	movdqa		xmm7, [rip+shufflemask]
	movdqa		xmm8, [rip+unit02_mask]
	movdqa		xmm9, [rip+unit13_mask]
	movdqa		xmm10, [rip+unit02_mulhi]
	movdqa		xmm11, [rip+unit13_mullo]
	movdqa		xmm12, [rip+satsub]
	movdqa		xmm13, [rip+capitals]
	movdqa		xmm14, [rip+cap_index]
	movdqa		xmm15, [rip+offsets]

	cmp		rbp, 24
	jb		.Llast
	jmp		.Lhot
	.p2align	6, 0x90

	# Encode a block of 24 bytes to base64.
	# xmm0: input
	# xmm7: shuffle mask
	# xmm8-xmm11: masks and shifts for splitting
	# xmm12-xmm15: tables for converting indices to Base64
	# Result in xmm0. Clobbers xmm1-xmm5.
.macro	encode_block
	# load and process data into 3 byte units
	pshufb		xmm0, xmm7
	# 11112222 22333333 00000011 11112222

	# process 3 byte units into base64 units
	movdqa		xmm1, xmm0
	pand		xmm1, xmm8
	movdqa		xmm2, xmm0
	pand		xmm2, xmm9
	pmulhuw		xmm1, xmm10
	pmullw		xmm2, xmm11
	por		xmm1, xmm2

	# convert into the Base64 character set
	movdqa		xmm0, xmm1
	psubusb		xmm1, xmm12
	movdqa		xmm2, xmm13
	pcmpgtb		xmm2, xmm0
	pand		xmm2, xmm14
	por		xmm1, xmm2
	movdqa		xmm2, xmm15
	pshufb		xmm2, xmm1
	paddb		xmm0, xmm2
	# final encoded form of 12 bytes in ymm0
.endm

# LLVM-MCA-BEGIN hot loop
.Lhot:
	# r13 = in, rbp = inlen, rbx = out, r12 = outlen
	# SSE don't support masked loads, and movdqu can segv if there
	# is less than 16 bytes remaining in input. In such a case, we
	# have to resort to memcpy, which is acceptable because it is
	# not in the hot path.
	prefetchnta	[r13+12]
	prefetchnta	[rbx+16]

	cmp		rbp, 16
	jb		.Lless_than_16bytes
	movdqu		xmm0, [r13]
.Lencode_fast:
	encode_block
	add		r13, 12
	sub		rbp, 12

	# check if the full vector can be copied into output
	cmp		r12, 16
	jb		.Ltruncate_output
	# copy
	movdqu		[rbx], xmm0
	add		rbx, 16
	sub		r12, 16
	cmp		rbp, 12
	jb		.Llast
	jmp		.Lhot
# LLVM-MCA-END hot loop

	.p2align	3, 0x90
.Lless_than_16bytes:
	mov		rdi, rsp
	mov		rsi, r13
	# inlen < 16 < UINT_MAX
	mov		edx, ebp
	call		memcpy@PLT

	movdqa		xmm0, [rsp]
	jmp		.Lencode_fast

	.p2align	3, 0x90
	# output can't accept enough bytes
.Ltruncate_output:
	movdqa		[rsp], xmm0
	mov		rdi, rbx
	mov		rsi, rsp
	mov		rdx, r12
	call		memcpy@PLT
	jmp		.Lcleanup

	.p2align	3, 0x90
	# less than 12 bytes remaining
.Llast:
	# shortcut for when zero bytes left
	test		rbp, rbp
	jz		.Lzero_terminate

	# clear buffer for final input at [rsp]
	pxor		xmm0, xmm0
	movdqa		[rsp], xmm0
	# copy final data to buffer
	# r13 = in, rbp = inlen, rbx = out, r12 = outlen
	mov		rdi, rsp
	mov		rsi, r13
	# inlen < 16 < UINT_MAX
	mov		edx, ebp
	call		memcpy@PLT

	movdqa		xmm0, [rsp]
	encode_block
	movdqa		[rsp], xmm0

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
	add		rsp, 24
	.cfi_adjust_cfa_offset	-24
	pop		r13
	.cfi_restore		r13
	.cfi_adjust_cfa_offset	-8
	pop		r12
	.cfi_restore		r12
	.cfi_adjust_cfa_offset	-8
	pop		rbp
	.cfi_restore		rbp
	.cfi_adjust_cfa_offset	-8
	pop		rbx
	.cfi_restore		rbx
	.cfi_adjust_cfa_offset	-8
	ret
	.cfi_endproc
	.size		base64_encode_core2, .-base64_encode_core2


	# void base64url_encode_core2 (const char *restrict in, size_t inlen,
	#                              char *restrict out, size_t outlen);
	.globl		base64url_encode_core2
	.type		base64url_encode_core2, @function
	.text
	.p2align	6, 0x90
base64url_encode_core2:
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
	push		r13
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		r13, 0
	# align the stack frame to 16-byte boundary (see x86_64 psABI)
	sub		rsp, 24
	.cfi_adjust_cfa_offset	24

	# save in -> r13, inlen -> rbp, out -> rbx, outlen -> r12
	mov		r13, rdi
	mov		rbp, rsi
	mov		rbx, rdx
	mov		r12, rcx

	movdqa		xmm7, [rip+shufflemask]
	movdqa		xmm15, [rip+offsets_url]
	movdqa		xmm8, [rip+unit02_mask]
	movdqa		xmm9, [rip+unit13_mask]
	movdqa		xmm10, [rip+unit02_mulhi]
	movdqa		xmm11, [rip+unit13_mullo]
	movdqa		xmm12, [rip+satsub]
	movdqa		xmm13, [rip+capitals]
	movdqa		xmm14, [rip+cap_index]

	cmp		rbp, 24
	jb		.Llast
	jmp		.Lhot
	.cfi_endproc
	.size		base64url_encode_core2, .-base64url_encode_core2


	.section	.rodata, "a", @progbits
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

	.p2align	4, 0x0
shufflemask:
	# 11112222 22333333 00000011 11112222
	.long		0x01020001, 0x04050304, 0x07080607, 0x090a0809
offsets_url:
	.byte		71, -4, -4, -4, -4, -4, -4, -4
	.byte		-4, -4, -4, -17, 32, 65, 0, 0

	.p2align	6, 0x0
unit02_mask:
	.fill		4, 4, 0x0fc0fc00
unit13_mask:
	.fill		4, 4, 0x003f03f0
unit02_mulhi:
	.fill		4, 4, 0x04000040
unit13_mullo:
	.fill		4, 4, 0x01000010
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
	.fill		16, 1, 51
capitals:
	.fill		16, 1, 26
cap_index:
	.fill		16, 1, 13
offsets:
	.byte		71, -4, -4, -4, -4, -4, -4, -4
	.byte		-4, -4, -4, -19, -16, 65, 0, 0
