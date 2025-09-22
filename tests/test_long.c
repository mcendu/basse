/*
 * Base64 decoding tests.
 * Copyright (C) 2025 Du Yijie.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

// The following test requires C23 to compile. If C23 is not available,
// this test is skipped.
#if __STDC_VERSION__ >= 202311L
#include "macros.h"

#include "ifunc.h"
#include <assert.h>
#include <stdlib.h>
#include <string.h>

static const char base64[] = {
#embed "data/COPYING.base64.nowrap" suffix(, 0)
};

static const char b64_wrapped[] = {
#embed "data/COPYING.base64" suffix(, 0)
};

static const char plain[] = {
#embed "data/COPYING" suffix(, 0)
};

#define OUTPUT_BUFFER_SIZE 65536

static void
test_encode (base64_encode_function encode)
{
  char *buf = malloc (OUTPUT_BUFFER_SIZE);

  encode (plain, strlen (plain), buf, OUTPUT_BUFFER_SIZE);
  ASSERT (strlen (buf) == strlen (base64));
  ASSERT (memcmp (buf, base64, strlen (base64)) == 0);

  free (buf);
}

static void
test_decode (base64_decode_function decode,
             base64_decoder_size_function decoder_size,
             base64_decoder_init_function decoder_init)
{
  struct base64_decoder *ctx = malloc (decoder_size ());
  decoder_init (ctx);
  char *buf = malloc (OUTPUT_BUFFER_SIZE);
  size_t outlen = OUTPUT_BUFFER_SIZE;

  ASSERT (decode (ctx, b64_wrapped, strlen (b64_wrapped), buf, &outlen));
  ASSERT (outlen == strlen (plain));
  ASSERT (memcmp (buf, plain, strlen (plain)) == 0);

  free (buf);
  free (ctx);
}

#define PARTIAL_OUTPUT_UNITS 4096

static void
test_decode_partial (base64_decode_function decode,
                     base64_decoder_size_function decoder_size,
                     base64_decoder_init_function decoder_init)
{
  struct base64_decoder *ctx = malloc (decoder_size ());
  decoder_init (ctx);
  char *buf = malloc (PARTIAL_OUTPUT_UNITS * 3);
  size_t outlen = PARTIAL_OUTPUT_UNITS * 3;

  ASSERT (decode (ctx, b64_wrapped, strlen (b64_wrapped), buf, &outlen));
  ASSERT (outlen == PARTIAL_OUTPUT_UNITS * 3);
  ASSERT (memcmp (buf, plain, outlen) == 0);

  free (buf);
  free (ctx);
}

int
main (void)
{
#ifdef __x86_64__
  __builtin_cpu_init ();

  if (__builtin_cpu_supports ("avx512vbmi2"))
    {
      test_encode (base64_encode_znver4);
      test_decode (base64_decode_znver4, base64_decoder_size_znver4,
                   base64_decoder_init_znver4);
      test_decode_partial (base64_decode_znver4, base64_decoder_size_znver4,
                           base64_decoder_init_znver4);
    }

  if (__builtin_cpu_supports ("avx2"))
    {
      test_encode (base64_encode_haswell);
      test_decode (base64_decode_haswell, base64_decoder_size_haswell,
                   base64_decoder_init_haswell);
      test_decode_partial (base64_decode_haswell, base64_decoder_size_haswell,
                           base64_decoder_init_haswell);
    }

  if (__builtin_cpu_supports ("sse4.1") && __builtin_cpu_supports ("popcnt"))
    {
      test_decode (base64_decode_nehalem, base64_decoder_size_nehalem,
                   base64_decoder_init_nehalem);
      test_decode_partial (base64_decode_nehalem, base64_decoder_size_nehalem,
                           base64_decoder_init_nehalem);
    }

  if (__builtin_cpu_supports ("ssse3"))
    {
      test_encode (base64_encode_core2);
    }
#endif /* __x86_64__ */

#ifdef __aarch64__
  test_encode (base64_encode_aarch64);
#endif

  test_encode (base64_encode_generic);
  test_decode (base64_decode_generic, base64_decoder_size_generic,
               base64_decoder_init_generic);
  test_decode_partial (base64_decode_generic, base64_decoder_size_generic,
                       base64_decoder_init_generic);

  return test_exit_status;
}
#else
int
main (void)
{
  return 77;
}
#endif
