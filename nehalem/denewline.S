	# Removes newlines from the input data using SSSE3.
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

	# Based on work by Daniel Lemire in
	# <https://github.com/lemire/despacer>.
	.intel_syntax	noprefix

	.globl		base64_denewline_nehalem
	.type		base64_denewline_nehalem, @function
	.text
	.p2align	6, 0x90
base64_denewline_nehalem:
	.cfi_startproc
	mov		r11, [rip+base64_denewline_indices@GOTPCREL]

	# original dst pointer
	mov		rcx, rdi

	cmp		rdx, 16
	jb		.Llast
	.p2align	6, 0x90
.Lhot:
	prefetchnta	[rsi+16]
	prefetchnta	[rdi+16]

	movdqu		xmm0, [rsi]
	movdqa		xmm1, [rip+cr]
	movdqa		xmm2, [rip+lf]
	pcmpeqb		xmm1, xmm0
	pcmpeqb		xmm2, xmm0
	por		xmm1, xmm2
	pmovmskb	eax, xmm1
	pmovmskb	r8d, xmm1

	xor		eax, 0xffff
	popcnt		eax, eax
	and		r8d, 0x7fff

	shl		r8, 4
	movdqa		xmm2, [r11+r8]
	pshufb		xmm0, xmm2
	movdqu		[rdi], xmm0

	add		rsi, 16
	sub		rdx, 16
	add		rdi, rax
	cmp		rdx, 16
	jae		.Lhot
.Llast:
	test		edx, edx
	jz		.Lcleanup
	jmp		.Lscalar_loop

	# There is no byte-granularity masked stores. Since this is out of the
	# hot zone anyway, we can do away with removing newlines byte by byte.
	.p2align	6, 0x90
.Lscalar_loop:
	lea		r9, [rdi+1]
	movzx		r8d, byte ptr [rsi]
	inc		rsi
	mov		[rdi], r8b
	cmp		r8, 0x0a # \n
	cmove		r9, rdi
	cmp		r8, 0x0d # \r
	cmove		r9, rdi
	mov		rdi, r9
	dec		edx
	jnz		.Lscalar_loop
.Lcleanup:
	mov		rax, rdi
	sub		rax, rcx
	ret

	.cfi_endproc
	.size		base64_denewline_nehalem, .-base64_denewline_nehalem

	.section	.rodata, "a", @progbits
	.p2align	4
cr:
	.ascii		"\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r\r"
lf:
	.ascii		"\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
