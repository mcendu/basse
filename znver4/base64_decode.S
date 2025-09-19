	# Fast path of Base64 decoding for Zen 4 and later AMD architectures,
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

#include "base64_decode.h"

	# bool base64_decode_main_znver4(const char *restrict in,
	#                                idx_t *restrict inlen,
	#                                char *restrict out,
	#                                idx_t *restrict outlen);
	.globl		base64_decode_main_znver4
	.type		base64_decode_main_znver4, @function
	.text
	.p2align	6, 0x90
base64_decode_main_znver4:
	.cfi_startproc
	push		rbx
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		rbx, 0
	push		r12
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		r12, 0
	push		r13
	.cfi_adjust_cfa_offset	8
	.cfi_rel_offset		r13, 0
	# pushing the pointer parameters to free up registers
	push		rsi
	.cfi_adjust_cfa_offset	8
	push		rcx
	.cfi_adjust_cfa_offset	8
	.cfi_remember_state

	prefetchnta	[rdi]
	prefetchnta	[rdx]

	# initialize input and output remaining counters
	mov		rsi, [rsi]
	mov		rcx, [rcx]

	# constants for swizzling base64 units into 3-byte groups
	mov		eax, 0x01400140 # swap & merge step 1
	mov		ebx, 0x00011000 # swap & merge step 2
	# compress mask
	mov		r12, 0x0fff0fff0fff0fff

	vpbroadcastd	zmm12, eax
	vpbroadcastd	zmm13, ebx
	vmovdqa64	zmm14, [rip+map_q0]
	vmovdqa64	zmm15, [rip+map_q1]
	vbroadcasti32x4	zmm11, [rip+shuffle]
	kmovq		k7, r12

	cmp		rsi, 64
	jbe		.Llast
	jmp		.Lhot

	# decode a block of base64 data
	# zmm0: input
	# zmm11-13: swizzle control
	# zmm14-15: ascii to raw value mapping
	# returns in zmm0, clobbers zmm1-zmm7, rax, r8
.macro	decode_block	mask
	vpxor		xmm1, xmm1, xmm1

	# check for 0x80-0xff
	vpcmpltb	k0 \mask , zmm0, zmm1
	# lookup
	vpermi2b	zmm0, zmm14, zmm15
	# check for bytes mapping nowhere
	vpcmpltb	k1 \mask , zmm0, zmm1
	korq		k0, k0, k1
	# reject invalid input
	ktestq		k0, k0
	jnz		.Lreject

	# swizzle
	vpmaddubsw	zmm0, zmm0, zmm12
	vpmaddwd	zmm0, zmm0, zmm13
	vpshufb		zmm0, zmm0, zmm11
	# result in zmm0 ready for storing with vpcompressb
.endm

	.p2align	6, 0x90
# LLVM-MCA-BEGIN hot loop
.Lhot:
	prefetchnta	[rdi+64]
	prefetchnta	[rdx+48]

	vmovdqu8	zmm0, [rdi]
	decode_block
	add		rdi, 64
	sub		rsi, 64

	# store
	cmp		rcx, 48
	jb		.Ltruncate_output
	vpcompressb	[rdx] {k7}, zmm0
	add		rdx, 48
	sub		rcx, 48
	cmp		rsi, 64
	jbe		.Llast
	jmp		.Lhot
# LLVM-MCA-END hot loop

	# not enough bytes to store
	.p2align	3, 0x90
.Ltruncate_output:
	# only output in multiple of 3 bytes for caller's sanity
	vpcompressb	zmm1 {k7}{z}, zmm0
	imul		eax, ecx, 0xaaab
	shr		eax, 17
	mov		edi, eax
	shl		edi, 2           # input processed for this block
	lea		eax, [rax+rax*2] # output processed for this block

	mov		r8, 1
	shlx		r8, r8, rax
	dec		r8
	kmovq		k1, r8
	vmovdqu8	[rdx] {k1}, zmm1
	sub		rsi, rdi
	sub		ecx, eax

	# write input and output processed
	mov		rdi, [rsp+8]
	mov		rax, [rsp]
	sub		[rdi], rsi
	sub		[rax], rcx
	mov		eax, BASE64_DECODE_TRUNCATED_OUTPUT
	jmp		.Lcleanup

	# last block
	.p2align	3, 0x90
.Llast:
	# shortcut if zero bytes left
	test		esi, esi
	jz		.Lnoinput

	# padding character match mask
	mov		r8d, 0x3d3d3d3d # "===="
	vpbroadcastd	zmm7, r8d
	# replace lookup table to allow for padding characters
	vmovdqa64	zmm14, [rip+map_q0_last]

	# only load input in multiples of 4 bytes
	mov		rbx, rsi
	and		ebx, 0xfffffffc
	# corresponding output count
	mov		r12, rbx
	shr		r12, 2
	lea		r12, [r12+r12*2]
	# mask load final block
	xor		r8, r8
	mov		eax, 1
	shlx		rax, rax, rbx
	cmp		ebx, 64
	cmove		rax, r8
	dec		rax
	kmovq		k6, rax
	vmovdqu8	zmm0 {k6}{z}, [rdi]

	# check for padding
	vpcmpeqb	k0, zmm0, zmm7
	kmovq		r8, k0
	tzcnt		rax, r8 # position of first padding
	popcnt		r8, r8  # number of padding bytes
	cmovz		eax, ebx
	# reject most cases of illegal paddings
	mov		r9, rbx
	sub		r9, rax
	cmp		r9, 2
	ja		.Lreject
	# reject data ending with something like '=X'
	cmp		r9, r8
	jne		.Lreject
	# update bytes to output
	sub		r12, r8

	# check how many bytes we can actually output
	xor		r13, r13
	cmp		rcx, r12
	jae		.Ldecode_last
	# calculate the amount of input to take
	mov		r13, r12
	imul		r9d, ecx, 0xaaab
	shr		r9d, 17
	mov		r10d, r9d
	shl		r10d, 2       # how much input is takeable
	lea		r9, [r9+r9*2] # how much to output
	# compare against actual output buffer remaining
	mov		rbx, r10
	mov		r12, r9
	# save number of bytes not outputted due to output buffer
	sub		r13, r12

.Ldecode_last:
	decode_block	{k6}

	# output
	vpcompressb	zmm0 {k7}{z}, zmm0
	mov		edi, 1
	shlx		rdi, rdi, r12
	dec		rdi
	kmovq		k1, rdi
	vmovdqu8	[rdx] {k1}, zmm0

	# write *inlen and *outlen
	mov		rdi, [rsp+8]
	mov		rdx, [rsp]
	sub		esi, ebx
	sub		rcx, r12
	sub		[rdi], rsi
	sub		[rdx], rcx
	# set status code
	xor		eax, eax
	mov		ecx, BASE64_DECODE_INCOMPLETE_INPUT
	mov		edx, BASE64_DECODE_TRUNCATED_OUTPUT
	test		esi, 3
	cmovnz		eax, ecx
	test		r13, r13
	cmovnz		eax, edx
.Lcleanup:
	add		rsp, 16
	.cfi_adjust_cfa_offset	-16
	pop		r13
	.cfi_restore		r13
	.cfi_adjust_cfa_offset	-8
	pop		r12
	.cfi_restore		r12
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
	mov		rdi, [rsp]
	sub		[rdi], rcx
	xor		eax, eax
	jmp		.Lcleanup

	# block rejected as invalid
	.p2align	3, 0x90
.Lreject:
	# write *inlen and *outlen
	mov		rdi, [rsp+8]
	mov		rdx, [rsp]
	sub		[rdi], rsi
	sub		[rdx], rcx
	mov		eax, BASE64_DECODE_REJECTED
	jmp		.Lcleanup
	.cfi_endproc
	.size		base64_decode_main_znver4, .-base64_decode_main_znver4


	#   | 3  2  1  0   7  6  5  4   b  a  9  8   f  e  d  c
	# --+---------------------------------------------------
	# 0 | ^C ^B ^A \0  ^G ^F ^E ^D  ^K \n \t ^H  ^O ^N \r ^L
	# 1 | ^S ^R ^Q ^P  ^W ^V ^U ^T  ^[ ^Z ^Y ^X  ^_ ^^ ^] ^\
	# 2 | #  "  !      '  &  %  $   +  *  )  (   /  .  -  ,
	# 3 | 3  2  1  0   7  6  5  4   ;  :  9  8   ?  >  =  <
	# 4 | C  B  A  @   G  D  F  E   K  J  I  H   O  N  M  L
	# 5 | P  Q  R  S   W  V  U  T   [  Z  Y  X   _  ^  ]  \
	# 6 | c  b  a  `   g  d  f  e   k  j  i  h   o  n  m  l
	# 7 | s  r  q  p   w  v  u  t   {  z  y  x   ^? ~  }  |
	.section	.rodata, "a", @progbits
	.p2align	6, 0x0
#ifdef BASE64_URL
map_q0:
	.long		0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff
	.long		0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff
	.long		0xffffffff, 0xffffffff, 0xffffffff, 0xffff3eff
	.long		0x37363534, 0x3b3a3938, 0xffff3d3c, 0xffffffff
map_q1:
	.long		0x020100ff, 0x06050403, 0x0a090807, 0x0e0d0c0b
	.long		0x1211100f, 0x16151413, 0xff191817, 0x3fffffff
	.long		0x1c1b1aff, 0x201f1e1d, 0x24232221, 0x28272625
	.long		0x2c2b2a29, 0x302f2e2d, 0xff333231, 0xffffffff
map_q0_last:
	.long		0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff
	.long		0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff
	.long		0xffffffff, 0xffffffff, 0xffffffff, 0xffff3eff
	.long		0x37363534, 0x3b3a3938, 0xffff3d3c, 0xffff00ff
#else
map_q0:
	.long		0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff
	.long		0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff
	.long		0xffffffff, 0xffffffff, 0x3effffff, 0x3fffffff
	.long		0x37363534, 0x3b3a3938, 0xffff3d3c, 0xffffffff
map_q1:
	.long		0x020100ff, 0x06050403, 0x0a090807, 0x0e0d0c0b
	.long		0x1211100f, 0x16151413, 0xff191817, 0xffffffff
	.long		0x1c1b1aff, 0x201f1e1d, 0x24232221, 0x28272625
	.long		0x2c2b2a29, 0x302f2e2d, 0xff333231, 0xffffffff
map_q0_last:
	.long		0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff
	.long		0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff
	.long		0xffffffff, 0xffffffff, 0x3effffff, 0x3fffffff
	.long		0x37363534, 0x3b3a3938, 0xffff3d3c, 0xffff00ff
#endif
shuffle:
	.byte		0x02, 0x01, 0x00, 0x06, 0x05, 0x04, 0x0a, 0x09
	.byte		0x08, 0x0e, 0x0d, 0x0c, 0xff, 0xff, 0xff, 0xff
