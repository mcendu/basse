	# Fast path of Base64 decoding using AVX2.
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

	# bool base64_decode_main_haswell(const char *restrict in,
	#                                 idx_t *restrict inlen,
	#                                 char *restrict out,
	#                                 idx_t *restrict outlen);
	.globl		base64_decode_main_haswell
	.type		base64_decode_main_haswell, @function
	.text
	.p2align	6, 0x90
base64_decode_main_haswell:
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
	sub		rsp, 40
	.cfi_adjust_cfa_offset	40
	.cfi_remember_state

	# save *inlen -> rbx, out -> rbp, *outlen -> r12
	mov		rbx, [rsi]
	mov		rbp, rdx
	mov		r12, [rcx]

	prefetchnta	[rdi]
	prefetchnta	[rbp]

	vbroadcasti128	ymm8, [rip+row_check]
	vbroadcasti128	ymm9, [rip+column_check]
	vbroadcasti128	ymm10, [rip+offsets]
	vpbroadcastw	ymm11, [rip+sixtythird]
	vpbroadcastw	ymm12, [rip+sixtythird_indexdiff]
	vpbroadcastd	ymm5, [rip+low4_mask]
	vpbroadcastd	ymm13, [rip+swapmerge1]
	vpbroadcastd	ymm14, [rip+swapmerge2]
	vmovdqa		ymm6, [rip+storemask]
	vmovdqa		ymm7, [rip+shuffle2]
	vbroadcasti128	ymm15, [rip+shuffle1]

	cmp		rbx, 32
	jb		.Llast
	jmp		.Lhot

.macro	decode_block
	# check validity
	vpsrlw		ymm2, ymm0, 4
	vpand		ymm1, ymm0, ymm5
	vpand		ymm2, ymm2, ymm5
	vpshufb		ymm1, ymm8, ymm1
	vpshufb		ymm3, ymm9, ymm2
	vptest		ymm1, ymm3
	jnz		.Lreject
	# map from base64 to index
	vpshufb		ymm2, ymm10, ymm2
	vpcmpeqb	ymm1, ymm0, ymm11
	vpand		ymm1, ymm1, ymm12
	vpaddb		ymm0, ymm0, ymm1
	vpaddb		ymm0, ymm0, ymm2
	# swizzle to 3 raw bytes
	vpmaddubsw	ymm0, ymm0, ymm13
	vpmaddwd	ymm0, ymm0, ymm14
	# pack
	vpshufb		ymm0, ymm0, ymm15
	vpermd		ymm0, ymm7, ymm0
	# result in ymm0
.endm

	.p2align	6, 0x90
# LLVM-MCA-BEGIN hot loop
.Lhot:
	prefetchnta	[rdi+32]
	prefetchnta	[rbp+24]

	vmovdqu		ymm0, [rdi]
	decode_block
	add		rdi, 32
	sub		rbx, 32

	# store
	cmp		r12, 24
	jb		.Ltruncate_output
	vpmaskmovd	[rbp], ymm6, ymm0
	add		rbp, 24
	sub		r12, 24
	cmp		rbx, 32
	jbe		.Llast
	jmp		.Lhot
# LLVM-MCA-END hot loop

	# not enough bytes to store
	.p2align	3, 0x90
.Ltruncate_output:
	vmovdqu		[rsp], ymm0
	# only output in multiple of 3 bytes for caller's sanity
	imul		r13d, r12d, 0xaaab
	shr		r13d, 17
	mov		r14, r13
	shl		r14, 2           # input processed
	lea		r13, [r13+r13*2] # output processed

	# save input/output processed, then memcpy
	mov		rdi, rbp
	mov		rsi, rsp
	mov		rdx, r13
	call		memcpy@PLT

	# write input and output processed
	mov		rsi, [rsp+48]
	mov		rdi, [rsp+40]
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
	vpbroadcastd	ymm2, [rip+base64_zeros]
	vmovdqu		[rsp], ymm2

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
	mov		rdx, r13
	call		memcpy@PLT

	# check for padding
	vmovdqu		ymm0, [rsp]
	vpbroadcastd	ymm1, [rip+padding]
	vpbroadcastd	ymm2, [rip+base64_zeros]
	vpcmpeqb	ymm3, ymm0, ymm1
	vpmovmskb	eax, ymm3
	tzcnt		ecx, eax # position of first padding
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
	vpand		ymm2, ymm2, ymm3
	vpandn		ymm0, ymm3, ymm0
	vpor		ymm0, ymm0, ymm2
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
	vmovdqu		[rsp], ymm0

	# output
	mov		rdi, rbp
	mov		rsi, rsp
	mov		rdx, r14
	call		memcpy@PLT

	# write *inlen and *outlen
	mov		rdi, [rsp+48]
	mov		rsi, [rsp+40]
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
	add		rsp, 56
	.cfi_adjust_cfa_offset	-56
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
	mov		rdi, [rsp+40]
	sub		[rdi], r12
	xor		eax, eax
	jmp		.Lcleanup

	# block rejected as invalid
	.p2align	3, 0x90
.Lreject:
	# write *inlen and *outlen
	mov		rdi, [rsp+48]
	mov		rdx, [rsp+40]
	sub		[rdi], rbx
	sub		[rdx], r12
	mov		eax, BASE64_DECODE_REJECTED
	jmp		.Lcleanup
	.cfi_endproc
	.size		base64_decode_main_haswell, .-base64_decode_main_haswell

	.section	.rodata, "a", @progbits
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
sixtythird:
	.ascii		"//"
sixtythird_indexdiff:
	.byte		-1, -1
low4_mask:
	.long		0x0f0f0f0f
swapmerge1:
	.byte		0x40, 0x01, 0x40, 0x01
swapmerge2:
	.word		0x1000, 0x0001

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
sixtythird_url:
	.ascii		"__"
sixtythird_indexdiff_url:
	.byte		-4, -4
low4_mask_url:
	.long		0x0f0f0f0f
swapmerge1_url:
	.byte		0x40, 0x01, 0x40, 0x01
swapmerge2_url:
	.word		0x1000, 0x0001

	.p2align	6, 0x90
storemask:
	.long		-1, -1, -1, -1, -1, -1, 0, 0
shuffle2:
	.long		0, 1, 2, 4, 5, 6, -1, -1
	.p2align	6, 0x90
shuffle1:
	.byte		0x02, 0x01, 0x00, 0x06, 0x05, 0x04, 0x0a, 0x09
	.byte		0x08, 0x0e, 0x0d, 0x0c, 0xff, 0xff, 0xff, 0xff
padding:
	.ascii		"===="
base64_zeros:
	.ascii		"AAAA"
