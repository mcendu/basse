	# Fast Base64 encoding for Zen 4 and later AMD microarchitectures,
	# along with a few Intel processors.
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


	# void base64_encode_znver4 (const char *restrict in, size_t inlen,
	#                            char *restrict out, size_t outlen);
	.globl		base64_encode_znver4
	.type		base64_encode_znver4, @function
	.text
	.p2align	6, 0x90
base64_encode_znver4:
	.cfi_startproc
	.cfi_def_cfa		rsp, 8
	push		rbx
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		rbx, 0
	push		rbp
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		rbp, 0
	push		r12
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		r12, 0
	sub		rsp, 64
	.cfi_adjust_cfa_offset	64

	prefetchnta	[rdi]
	prefetchnta	[rdx]

	# vpexpandb mask
	mov		rax, 0x7777777777777777
	kmovq		k1, rax
	# constants for swizzling 3-byte units into base64 units
	mov		r8d, 0x0fc0fc00  # char 0 and char 2 mask
	mov		r9d, 0x003f03f0  # char 1 and char 3 mask
	mov		r10d, 0x0006000a # char 0 and char 2 shift
	mov		r11d, 0x00080004 # char 1 and char 3 shift

	vmovdqa64	zmm9, [rip+chars]
	vbroadcasti32x4	zmm11, [rip+seq_shuffle]
	vpbroadcastd	zmm12, r8d
	vpbroadcastd	zmm13, r9d
	vpbroadcastd	zmm14, r10d
	vpbroadcastd	zmm15, r11d

	cmp		rsi, 48
	jb		.Llast
	jmp		.Lhot

	# Encode a block of 48 bytes to base64.
	#
	# The result is put into zmm0. zmm1-zmm7 are also clobbered.
	# k1 holds the mask for loading from inptr. zmm11-15 contains
	# the masks and shifts used to process 3-byte units into
	# base64 units.
.macro	encode_block	inptr
	vpexpandb	zmm0 {k1}{z}, [\inptr]
	vpshufb		zmm0, zmm0, zmm11
	# 11112222 22333333 00000011 11112222
	vpandd		zmm1, zmm0, zmm12
	vpandd		zmm2, zmm0, zmm13
	vpsrlvw		zmm1, zmm1, zmm14
	vpsllvw		zmm2, zmm2, zmm15
	vpord		zmm0, zmm1, zmm2
	vpermb		zmm0, zmm0, zmm9
	# final encoded form of 48 bytes in zmm0
.endm

	.p2align	6, 0x90
# LLVM-MCA-BEGIN hot loop
.Lhot:
	prefetchnta	[rdi+48]
	prefetchnta	[rdx+64]

	encode_block	rdi
	add		rdi, 48
	sub		rsi, 48

	# check if the full vector can be copied into output
	cmp		rcx, 64
	jb		.Ltruncate_output
	# copy
	vmovdqu8	[rdx], zmm0
	add		rdx, 64
	sub		rcx, 64
	cmp		rsi, 48
	jb		.Llast
	jmp		.Lhot
# LLVM-MCA-END hot loop

	.p2align	4, 0x90
	# not enough bytes
.Ltruncate_output:
	vmovdqu64	[rsp], zmm0
	mov		rdi, rdx
	mov		rsi, rsp
	mov		rdx, rcx
	call		memcpy@PLT
	jmp		.Lcleanup

	.p2align	4, 0x90
.Llast:
	# save out -> rbx, inlen -> rbp, outlen -> r12
	# (using esi and ebp as inlen < 24 < UINT_MAX)
	mov		rbx, rdx
	mov		ebp, esi
	mov		r12, rcx
	# shortcut for when zero bytes left
	test		rsi, rsi
	jz		.Lzero_terminate

	# clear buffer for final input at [rsp]
	vpxord		zmm0, zmm0, zmm0
	vmovdqu64	[rsp], zmm0
	# copy final data to buffer
	mov		edx, esi
	mov		rsi, rdi
	mov		rdi, rsp
	call		memcpy@PLT

	encode_block	rsp
	vmovdqu64	[rsp], zmm0

	# full_units (rax) = inlen / 3
	imul		eax, ebp, 0xaaab
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
	add		rsp, 64
	.cfi_adjust_cfa_offset	-64
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
	.size		base64_encode_znver4, .-base64_encode_znver4


	# void base64url_encode_znver4 (const char *restrict in, size_t inlen,
	#                               char *restrict out, size_t outlen);
	.globl		base64url_encode_znver4
	.type		base64url_encode_znver4, @function
	.text
	.p2align	6, 0x90
base64url_encode_znver4:
	.cfi_startproc
	.cfi_def_cfa		rsp, 8
	push		rbx
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		rbx, 0
	push		rbp
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		rbp, 0
	push		r12
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		r12, 0
	sub		rsp, 64
	.cfi_adjust_cfa_offset	64

	# vpexpandb mask
	mov		rax, 0x7777777777777777
	kmovq		k1, rax
	# constants for swizzling 3-byte units into base64 units
	mov		eax, 0x00c000fc  # byte 0 and lower byte 2 mask
	mov		ebx, 0x003f0003  # higher byte 1 and byte 3 mask
	mov		r8d, 0x0000f000  # lower byte 1 mask
	mov		r9d, 0x00000f00  # higher byte 2 mask
	mov		r10d, 0x00060002 # byte 0 and lower byte 2 shift
	mov		r11d, 0x0008000c # higher byte 1 and byte 3 shift

	vmovdqa64	zmm9, [rip+chars_url]
	vpbroadcastd	zmm10, eax
	vpbroadcastd	zmm11, ebx
	vpbroadcastd	zmm12, r8d
	vpbroadcastd	zmm13, r9d
	vpbroadcastd	zmm14, r10d
	vpbroadcastd	zmm15, r11d

	cmp		rsi, 48
	jb		.Llast
	jmp		.Lhot
	.cfi_endproc
	.size		base64url_encode_znver4, .-base64url_encode_znver4


	.section	.rodata, "a", @progbits
	.p2align	6, 0x0
chars:
	.ascii		"ABCDEFGHIJKLMNOP"
	.ascii		"QRSTUVWXYZabcdef"
	.ascii		"ghijklmnopqrstuv"
	.ascii		"wxyz0123456789+/"
chars_url:
	.ascii		"ABCDEFGHIJKLMNOP"
	.ascii		"QRSTUVWXYZabcdef"
	.ascii		"ghijklmnopqrstuv"
	.ascii		"wxyz0123456789-_"
seq_shuffle:
	.long		0x01020001, 0x05060405, 0x090a0809, 0x0d0e0c0d
	.p2align	5, 0x0
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
