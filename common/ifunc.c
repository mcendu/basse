/*
 * ifunc resolvers for base64-related functions.
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
#include "ifunc.h"
#include <stdbool.h>

static base64_encode_function
resolve_base64_encode (void)
{
#ifdef __x86_64__
  __builtin_cpu_init ();

  if (__builtin_cpu_supports ("avx512vbmi2"))
    {
      return base64_encode_znver4;
    }
  else if (__builtin_cpu_supports ("avx2"))
    {
      return base64_encode_haswell;
    }
  else if (__builtin_cpu_supports ("ssse3"))
    {
      return base64_encode_core2;
    }
#endif

#ifdef __aarch64__
  return base64_encode_aarch64;
#endif

  return base64_encode_generic;
}

static base64_encode_function
resolve_base64url_encode (void)
{
#ifdef __x86_64__
  __builtin_cpu_init ();

  if (__builtin_cpu_supports ("avx512vbmi2"))
    {
      return base64url_encode_znver4;
    }
  else if (__builtin_cpu_supports ("avx2"))
    {
      return base64url_encode_haswell;
    }
  else if (__builtin_cpu_supports ("ssse3"))
    {
      return base64url_encode_core2;
    }
#endif

#ifdef __aarch64__
  return base64url_encode_aarch64;
#endif

  return base64url_encode_generic;
}

static base64_decoder_size_function
resolve_base64_decoder_size (void)
{
#ifdef __x86_64__
  __builtin_cpu_init ();

  if (__builtin_cpu_supports ("avx512vbmi2"))
    {
      return base64_decoder_size_znver4;
    }
  else if (__builtin_cpu_supports ("avx2"))
    {
      return base64_decoder_size_haswell;
    }
  else if (__builtin_cpu_supports ("sse4.1")
           && __builtin_cpu_supports ("popcnt"))
    {
      return base64_decoder_size_nehalem;
    }
#endif

  return base64_decoder_size_generic;
}

static base64_decoder_init_function
resolve_base64_decoder_init (void)
{
#ifdef __x86_64__
  __builtin_cpu_init ();

  if (__builtin_cpu_supports ("avx512vbmi2"))
    {
      return base64_decoder_init_znver4;
    }
  else if (__builtin_cpu_supports ("avx2"))
    {
      return base64_decoder_init_haswell;
    }
  else if (__builtin_cpu_supports ("sse4.1")
           && __builtin_cpu_supports ("popcnt"))
    {
      return base64_decoder_init_nehalem;
    }
#endif

  return base64_decoder_init_generic;
}

static base64_decode_function
resolve_base64_decode (void)
{
#ifdef __x86_64__
  __builtin_cpu_init ();

  if (__builtin_cpu_supports ("avx512vbmi2"))
    {
      return base64_decode_znver4;
    }
  else if (__builtin_cpu_supports ("avx2"))
    {
      return base64_decode_haswell;
    }
  else if (__builtin_cpu_supports ("sse4.1")
           && __builtin_cpu_supports ("popcnt"))
    {
      return base64_decode_nehalem;
    }
#endif

  return base64_decode_generic;
}

__attribute__ ((ifunc ("resolve_base64_encode"))) void
base64_encode (const char *restrict in, size_t inlen, char *restrict out,
               size_t outlen);

__attribute__ ((ifunc ("resolve_base64url_encode"))) void
base64url_encode (const char *restrict in, size_t inlen, char *restrict out,
                  size_t outlen);

__attribute__ ((ifunc ("resolve_base64_decoder_size"))) size_t
base64_decoder_size (void);

__attribute__ ((ifunc ("resolve_base64_decoder_init"))) void
base64_decoder_init (struct base64_decoder *ctx);

__attribute__ ((ifunc ("resolve_base64_decode"))) bool
base64_decode (struct base64_decoder *ctx, const char *restrict in,
               size_t inlen, char *restrict out, size_t *outlen);
