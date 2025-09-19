/* base64.h -- Encode binary data using printable characters.
   Copyright (C) 2004-2006, 2009-2025 Free Software Foundation, Inc.
   Written by Simon Josefsson.

   This file is free software: you can redistribute it and/or modify
   it under the terms of the GNU Lesser General Public License as
   published by the Free Software Foundation; either version 2.1 of the
   License, or (at your option) any later version.

   This file is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>.  */

#ifndef BASE64_H
#define BASE64_H

/* Get idx_t.  */
#include "idx.h"

#include <stdbool.h>

/* Pacify GCC in isubase64.  */
#if __GNUC__ + (3 <= __GNUC_MINOR__) > 4 && !defined(__clang__)
#pragma GCC diagnostic ignored "-Wtype-limits"
#elif defined(__clang__)
#pragma GCC diagnostic ignored "-Wtautological-constant-out-of-range-compare"
#endif

/* This uses that the expression (n+(k-1))/k means the smallest
   integer >= n/k, i.e., the ceiling of n/k.  */
#define BASE64_LENGTH(inlen) ((((inlen) + 2) / 3) * 4)

struct base64_decoder
{
  int i;
  char buf[4];
};

extern signed char const base64_to_int[256];

inline bool
isubase64 (unsigned char ch)
{
  return ch < sizeof base64_to_int && 0 <= base64_to_int[ch];
}

inline bool
isbase64 (char ch)
{
  return isubase64 (ch);
}

extern void base64_encode_generic (const char *restrict in, idx_t inlen,
                                   char *restrict out, idx_t outlen);

extern void base64url_encode_generic (const char *restrict in, idx_t inlen,
                                      char *restrict out, idx_t outlen);

inline size_t
base64_decoder_size_generic (void)
{
  return sizeof (struct base64_decoder);
}

/* Initialize decode-context buffer, CTX.  */
inline void
base64_decoder_init_generic (struct base64_decoder *ctx)
{
  ctx->i = 0;
}

extern bool base64_decode_generic (struct base64_decoder *ctx,
                                   const char *restrict in, idx_t inlen,
                                   char *restrict out, idx_t *outlen);

#endif /* BASE64_H */
