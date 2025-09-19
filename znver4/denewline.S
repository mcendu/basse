	# Removes newlines from the input data using AVX512VBMI2.
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

	.globl		base64_denewline_znver4
	.type		base64_denewline_znver4, @function
	.text
	.p2align	6, 0x90
base64_denewline_znver4:
	.cfi_startproc
	mov		eax, 0x0a0a0a0a # "\n\n\n\n"
	mov		ecx, 0x0d0d0d0d # "\r\r\r\r"
	vpbroadcastd	zmm14, eax
	vpbroadcastd	zmm15, ecx

	# original dst pointer
	mov		rcx, rdi

	cmp		rdx, 64
	jb		.Llast
	jmp		.Lhot

	.p2align	6, 0x20
.Lhot:
	prefetchnta	[rsi+64]
	prefetchnta	[rdi+64]

	vmovdqu8	zmm0, [rsi]
	vpcmpneqb	k0, zmm0, zmm14
	vpcmpneqb	k1, zmm0, zmm15
	kandq		k1, k0, k1
	vpcompressb	[rdi] {k1}, zmm0

	kmovq		rax, k1
	popcnt		rax, rax
	add		rsi, 64
	sub		rdx, 64
	add		rdi, rax
	cmp		rdx, 64
	jb		.Llast
	jmp		.Lhot
.Llast:
	mov		rax, rdi
	sub		rax, rcx
	test		edx, edx
	jz		.Lcleanup

	mov		ecx, 1
	shlx		rcx, rcx, rdx
	dec		rcx
	kmovq		k2, rcx
	vmovdqu8	zmm0 {k2}{z}, [rsi]
	vpcmpneqb	k0 {k2}, zmm0, zmm14
	vpcmpneqb	k1 {k2}, zmm0, zmm15
	kandq		k1, k0, k1
	vpcompressb	[rdi] {k1}, zmm0
	kmovq		rcx, k1
	popcnt		rcx, rcx
	add		rax, rcx
.Lcleanup:
	ret
	.cfi_endproc
	.size		base64_denewline_znver4, .-base64_denewline_znver4
