/*
 * Internal header for ifunc support.
 * Copyright (C) 2025 Du Yijie.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, see
 * <https://www.gnu.org/licenses/>.
 */
#ifndef IFUNC_H
#define IFUNC_H

#include "base64.h"

#include <stdbool.h>
#include <stddef.h>

/* Function prototypes. */

typedef void (*base64_encode_function) (const char *restrict in, size_t inlen,
                                        char *restrict out, size_t outlen);

typedef size_t (*base64_decoder_size_function) ();
typedef void (*base64_decoder_init_function) (
    struct base64_decoder *restrict ctx);
typedef bool (*base64_decode_function) (struct base64_decoder *restrict ctx,
                                        const char *restrict in, size_t inlen,
                                        char *restrict out,
                                        size_t *restrict outlen);

/* Portable functions. */

extern void base64_encode_generic (const char *restrict in, size_t inlen,
                                   char *restrict out, size_t outlen);
extern void base64url_encode_generic (const char *restrict in, size_t inlen,
                                      char *restrict out, size_t outlen);

extern size_t base64_decoder_size_generic ();
extern void base64_decoder_init_generic (struct base64_decoder *restrict ctx);
extern bool base64_decode_generic (struct base64_decoder *restrict ctx,
                                   const char *restrict in, size_t inlen,
                                   char *restrict out,
                                   size_t *restrict outlen);

#ifdef __x86_64__

/* Functions for x86-64 processors supporting SSSE3. */

extern void base64_encode_core2 (const char *restrict in, size_t inlen,
                                 char *restrict out, size_t outlen);
extern void base64url_encode_core2 (const char *restrict in, size_t inlen,
                                    char *restrict out, size_t outlen);

/* Functions for x86-64 processors supporting SSE4.1 + POPCNT. */

extern size_t base64_decoder_size_nehalem ();
extern void base64_decoder_init_nehalem (struct base64_decoder *restrict ctx);
extern bool base64_decode_nehalem (struct base64_decoder *restrict ctx,
                                   const char *restrict in, size_t inlen,
                                   char *restrict out,
                                   size_t *restrict outlen);

/* Functions for x86-64 processors supporting AVX2. */

extern void base64_encode_haswell (const char *restrict in, size_t inlen,
                                   char *restrict out, size_t outlen);
extern void base64url_encode_haswell (const char *restrict in, size_t inlen,
                                      char *restrict out, size_t outlen);

extern size_t base64_decoder_size_haswell ();
extern void base64_decoder_init_haswell (struct base64_decoder *restrict ctx);
extern bool base64_decode_haswell (struct base64_decoder *restrict ctx,
                                   const char *restrict in, size_t inlen,
                                   char *restrict out,
                                   size_t *restrict outlen);

/* Functions for x86-64 processors supporting AVX512F, BW, VBMI and VBMI2. */

extern void base64_encode_znver4 (const char *restrict in, size_t inlen,
                                  char *restrict out, size_t outlen);
extern void base64url_encode_znver4 (const char *restrict in, size_t inlen,
                                     char *restrict out, size_t outlen);

extern size_t base64_decoder_size_znver4 ();
extern void base64_decoder_init_znver4 (struct base64_decoder *restrict ctx);
extern bool base64_decode_znver4 (struct base64_decoder *restrict ctx,
                                  const char *restrict in, size_t inlen,
                                  char *restrict out, size_t *restrict outlen);

#endif /* __x86_64__ */

#ifdef __aarch64__

/* Functions for 64-bit ARM processors. */

extern void base64_encode_aarch64 (const char *restrict in, size_t inlen,
                                   char *restrict out, size_t outlen);
extern void base64url_encode_aarch64 (const char *restrict in, size_t inlen,
                                      char *restrict out, size_t outlen);

extern size_t base64_decoder_size_aarch64 ();
extern void base64_decoder_init_aarch64 (struct base64_decoder *restrict ctx);
extern bool base64_decode_aarch64 (struct base64_decoder *restrict ctx,
                                   const char *restrict in, size_t inlen,
                                   char *restrict out,
                                   size_t *restrict outlen);

#endif /* __aarch64__ */

#endif /* !IFUNC_H */
