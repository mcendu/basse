	# Removes newlines from the input data using AVX2.
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

	.globl		base64_denewline_haswell
	.type		base64_denewline_haswell, @function
	.text
	.p2align	6, 0x90
base64_denewline_haswell:
	.cfi_startproc
	vpbroadcastd	ymm14, [rip+cr]
	vpbroadcastd	ymm15, [rip+lf]
	mov		r11, [rip+base64_denewline_indices@GOTPCREL]

	# original dst pointer
	mov		rcx, rdi

	cmp		rdx, 32
	jb		.Llast
	jmp		.Lhot

	# Removes newlines from 32 bytes of data.
	# xmm0: input
	# xmm2: output (lower 16 bytes)
	# xmm3: output (higher 16 bytes)
	# xmm14: 32 bytes of '\r'
	# xmm15: 32 bytes of '\n'
	# rax: number of non-newlines in lower 16 bytes
	# r8:  total number of non-newlines
	# ymm1, r9, r10: clobbered
.macro	process_block
	vpcmpeqb	ymm1, ymm14, ymm0
	vpcmpeqb	ymm2, ymm15, ymm0
	vpor		ymm1, ymm1, ymm2
	vpmovmskb	eax, ymm1
	vpmovmskb	r8d, ymm1

	xor		r8d, 0xffffffff
	popcnt		r8, r8

	mov		r9, rax
	mov		r10, rax
	shr		r10, 16
	and		r9d, 0x7fff
	and		r10d, 0x7fff
	and		eax, 0xffff
	xor		eax, 0xffff
	popcnt		eax, eax

	shl		r9, 4
	shl		r10, 4
	vmovdqa		xmm2, [r11+r9]
	vbroadcasti128	ymm3, [r11+r10]
	vpshufb		xmm2, xmm0, xmm2
	vpshufb		ymm3, ymm0, ymm3
	vextracti128	xmm3, ymm3, 1
.endm

	.p2align	6, 0x90
.Lhot:
	prefetchnta	[rsi+32]
	prefetchnta	[rdi+32]

	vmovdqu		ymm0, [rsi]
	process_block
	vmovdqu		[rdi], xmm2
	vmovdqu		[rdi+rax], xmm3

	add		rsi, 32
	sub		rdx, 32
	add		rdi, r8
	cmp		rdx, 32
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
	.size		base64_denewline_haswell, .-base64_denewline_haswell

	.section	.rodata, "a", @progbits
	.p2align	4
cr:
	.ascii		"\r\r\r\r"
lf:
	.ascii		"\n\n\n\n"
