	# Fast path of Base64 decoding using SSE4.1 + POPCNT.
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

#include "base64_decode.h"

	# bool base64_decode_main_nehalem(const char *restrict in,
	#                               idx_t *restrict inlen,
	#                               char *restrict out,
	#                               idx_t *restrict outlen);
	.globl		base64_decode_main_nehalem
	.type		base64_decode_main_nehalem, @function
	.text
	.p2align	6, 0x90
base64_decode_main_nehalem:
	.cfi_startproc
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
	push		r14
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		r14, 0
	push		r15
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		r15, 0
	# pushing the pointer parameters to free up registers
	push		rsi
	.cfi_adjust_cfa_offset	8
	push		rcx
	.cfi_adjust_cfa_offset	8
	sub		rsp, 24
	.cfi_adjust_cfa_offset	24
	.cfi_remember_state

	# save *inlen -> rbx, out -> rbp, *outlen -> r12
	mov		rbx, [rsi]
	mov		rbp, rdx
	mov		r12, [rcx]

	prefetchnta	[rdi]
	prefetchnta	[rbp]

	movdqa		xmm11, [rip+sixtythird]
	movdqa		xmm12, [rip+sixtythird_indexdiff]
	movdqa		xmm7, [rip+low4_mask]
	movdqa		xmm13, [rip+swapmerge1]
	movdqa		xmm14, [rip+swapmerge2]
	movdqa		xmm15, [rip+shuffle1]

	cmp		rbx, 16
	jbe		.Llast
	jmp		.Lhot

.macro	decode_block
	# check validity
	movdqa		xmm1, xmm0
	movdqa		xmm2, xmm0
	movdqa		xmm3, [rip+row_check]
	movdqa		xmm4, [rip+column_check]
	psrlw		xmm2, 4
	pand		xmm1, xmm7
	pand		xmm2, xmm7
	pshufb		xmm3, xmm1
	pshufb		xmm4, xmm2
	ptest		xmm3, xmm4
	jnz		.Lreject
	# map from base64 to index
	movdqa		xmm1, xmm0
	movdqa		xmm3, [rip+offsets]
	pshufb		xmm3, xmm2
	pcmpeqb		xmm1, xmm11
	pand		xmm1, xmm12
	paddb		xmm0, xmm1
	paddb		xmm0, xmm3
	# swizzle to 3 raw bytes
	pmaddubsw	xmm0, xmm13
	pmaddwd		xmm0, xmm14
	# pack
	pshufb		xmm0, xmm15
	# result in xmm0
.endm

	.p2align	6, 0x90
# LLVM-MCA-BEGIN hot loop
.Lhot:
	prefetchnta	[rdi+16]
	prefetchnta	[rbp+12]

	movdqu		xmm0, [rdi]
	decode_block
	add		rdi, 16
	sub		rbx, 16

	# store
	cmp		r12, 12
	jb		.Ltruncate_output
	cmp		r12, 16
	jb		.Lstore_less_than_16bytes
	movdqu		[rbp], xmm0
	add		rbp, 12
	sub		r12, 12

	cmp		rbx, 16
	jbe		.Llast
	jmp		.Lhot
# LLVM-MCA-END hot loop

	.p2align	3, 0x90
.Lstore_less_than_16bytes:
	movdqa		[rsp], xmm0
	mov		r13, rdi
	mov		rdi, rbp
	mov		rsi, rsp
	mov		rcx, 12
	rep movsb
	mov		rdi, r13
	add		rbp, 12
	sub		r12, 12
	jmp		.Lhot

	# not enough bytes to store
	.p2align	3, 0x90
.Ltruncate_output:
	movdqa		[rsp], xmm0
	# only output in multiple of 3 bytes for caller's sanity
	imul		r13d, r12d, 0xaaab
	shr		r13d, 17
	mov		r14, r13
	shl		r14, 2           # input processed
	lea		r13, [r13+r13*2] # output processed

	# save input/output processed, then memcpy
	mov		rdi, rbp
	mov		rsi, rsp
	mov		rcx, r13
	rep movsb

	# write input and output processed
	mov		rsi, [rsp+32]
	mov		rdi, [rsp+24]
	sub		rbx, r14
	sub		r12, r13
	sub		[rsi], rbx
	sub		[rdi], r12
	mov		eax, BASE64_DECODE_TRUNCATED_OUTPUT
	jmp		.Lcleanup

	# last block
	.p2align	3, 0x90
.Llast:
	# shortcut if zero bytes left
	test		esi, esi
	jz		.Lnoinput

	# fill the input buffer
	movdqa		xmm2, [rip+base64_zeros]
	movdqa		[rsp], xmm2

	# only load input in multiples of 4 bytes
	mov		r13, rbx
	and		r13d, 0xfffffffc
	# corresponding output count
	mov		r14, r13
	shr		r14, 2
	lea		r14, [r14+r14*2]

	# copy final block to stack and load
	mov		rsi, rdi
	mov		rdi, rsp
	mov		rcx, r13
	rep movsb

	# check for padding
	movdqa		xmm0, [rsp]
	movdqa		xmm1, [rip+padding]
	movdqa		xmm2, [rip+base64_zeros]
	pcmpeqb		xmm1, xmm0
	pmovmskb	eax, xmm1
	bsf		ecx, eax # position of first padding
	popcnt		eax, eax # number of padding bytes
	cmovz		rcx, r13
	# reject most cases of illegal paddings
	mov		rdx, r13
	sub		edx, ecx
	cmp		edx, 2
	ja		.Lreject
	# reject data ending with something like '=X'
	cmp		edx, eax
	jne		.Lreject
	# replace padding with base64 zero in input vector
	pand		xmm2, xmm1
	pandn		xmm1, xmm0
	por		xmm1, xmm2
	movdqa		xmm0, xmm1
	# update bytes to output
	sub		r14, rax

	# check how many bytes we can actually output
	xor		r15, r15
	cmp		r12, r14
	jae		.Ldecode_last
	# calculate the amount of input to take
	mov		r15, r14
	imul		eax, r12d, 0xaaab
	shr		eax, 17
	mov		ecx, eax
	shl		ecx, 2           # how much input is takeable
	lea		eax, [rax+rax*2] # how much to output
	mov		r13, rcx
	mov		r14, rax
	# save number of bytes not outputted due to output buffer
	sub		r15, r14

.Ldecode_last:
	decode_block
	movdqu		[rsp], xmm0

	# output
	mov		rdi, rbp
	mov		rsi, rsp
	mov		rcx, r14
	rep movsb

	# write *inlen and *outlen
	mov		rdi, [rsp+32]
	mov		rsi, [rsp+24]
	sub		rbx, r13
	sub		r12, r14
	sub		[rdi], rbx
	sub		[rsi], r12
	# set status code
	xor		eax, eax
	mov		ecx, BASE64_DECODE_INCOMPLETE_INPUT
	mov		edx, BASE64_DECODE_TRUNCATED_OUTPUT
	test		ebx, 3
	cmovnz		eax, ecx
	test		r15, r15
	cmovnz		eax, edx
.Lcleanup:
	add		rsp, 40
	.cfi_adjust_cfa_offset	-40
	pop		r15
	.cfi_restore		r15
	.cfi_adjust_cfa_offset	-8
	pop		r14
	.cfi_restore		r14
	.cfi_adjust_cfa_offset	-8
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
	.cfi_adjust_cfa_offset	-8

	.p2align	3, 0x90
.Lnoinput:
	.cfi_restore_state
	# the entire input is processed so no need to update *inlen.
	# *outlen is updated as usual.
	mov		rdi, [rsp+24]
	sub		[rdi], r12
	xor		eax, eax
	jmp		.Lcleanup

	# block rejected as invalid
	.p2align	3, 0x90
.Lreject:
	# write *inlen and *outlen
	mov		rdi, [rsp+32]
	mov		rdx, [rsp+24]
	sub		[rdi], rbx
	sub		[rdx], r12
	mov		eax, BASE64_DECODE_REJECTED
	jmp		.Lcleanup
	.cfi_endproc
	.size		base64_decode_main_nehalem, .-base64_decode_main_nehalem

	.section	.rodata, "a", @progbits
	.p2align	6, 0x90
sixtythird:
	.ascii		"////////////////"
sixtythird_indexdiff:
	.fill		16, 1, -1
sixtythird_url:
	.ascii		"________________"
sixtythird_indexdiff_url:
	.byte		16, 1, -4
	.p2align	6, 0x90
low4_mask:
	.fill		16, 1, 0xf
swapmerge1:
	.fill		8, 2, 0x0140
swapmerge2:
	.fill		4, 4, 0x00011000
shuffle1:
	.byte		0x02, 0x01, 0x00, 0x06, 0x05, 0x04, 0x0a, 0x09
	.byte		0x08, 0x0e, 0x0d, 0x0c, 0xff, 0xff, 0xff, 0xff
	.p2align	6, 0x90
row_check:
	.byte		0x15, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11
	.byte		0x11, 0x11, 0x13, 0x1a, 0x1b, 0x1b, 0x1b, 0x1a
column_check:
	.byte		0x10, 0x10, 0x01, 0x02, 0x04, 0x08, 0x04, 0x08
	.byte		0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
offsets:
	.byte		0, 16, 19, 4, -65, -65, -71, -71
	.byte		0, 0, 0, 0, 0, 0, 0, 0
padding:
	.ascii		"================"
	.p2align	6, 0x90
row_check_url:
	.byte		0x95, 0x91, 0x91, 0x91, 0x91, 0x91, 0x91, 0x91
	.byte		0x91, 0x91, 0x93, 0x9b, 0x9b, 0x9a, 0x9b, 0x1b
column_check_url:
	.byte		0x10, 0x10, 0x01, 0x02, 0x04, 0x88, 0x04, 0x08
	.byte		0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10
offsets_url:
	.byte		0, -32, 17, 4, -65, -65, -71, -71
	.byte		0, 0, 0, 0, 0, 0, 0, 0
base64_zeros:
	.ascii		"AAAAAAAAAAAAAAAA"
