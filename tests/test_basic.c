/*
 * Basic functionality tests for Base64 encoding and decoding.
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
#include "macros.h"

#include "ifunc.h"
#include <assert.h>
#include <string.h>

static const char *test_raw[] = {
  "", "f", "fo", "foo", "foob", "fooba", "foobar",
};

static const char *test_encoded[] = {
  "", "Zg==", "Zm8=", "Zm9v", "Zm9vYg==", "Zm9vYmE=", "Zm9vYmFy",
};

static void
test_encode (base64_encode_function encode)
{
  char out[16];
  for (size_t i = 0; i < SIZEOF (test_raw); i++)
    {
      const char *in = test_raw[i];
      const char *expected = test_encoded[i];
      size_t expected_len = strlen (expected);

      encode (in, strlen (in), out, sizeof (out));
      ASSERT (strnlen (out, sizeof (out)) == expected_len);
      ASSERT (memcmp (out, expected, expected_len) == 0);
    }
}

static void
test_decode (base64_decode_function decode,
             base64_decoder_size_function decoder_size,
             base64_decoder_init_function decoder_init)
{
  char out[16];

  struct base64_decoder *dec = malloc (decoder_size ());
  ASSERT (dec != NULL);

  for (size_t i = 0; i < SIZEOF (test_encoded); i++)
    {
      const char *in = test_encoded[i];
      const char *expected = test_raw[i];
      size_t outlen = sizeof (out);

      decoder_init (dec);
      ASSERT (decode (dec, in, strlen (in), out, &outlen));
      ASSERT (outlen == strlen (expected));
      ASSERT (memcmp (out, expected, strlen (expected)) == 0);
    }

  free (dec);
}

int
main (void)
{
  __builtin_cpu_init ();

  if (__builtin_cpu_supports ("avx512vbmi2"))
    {
      test_encode (base64_encode_znver4);
      test_decode (base64_decode_znver4, base64_decoder_size_znver4,
                   base64_decoder_init_znver4);
    }

  if (__builtin_cpu_supports ("avx2"))
    {
      test_encode (base64_encode_haswell);
      test_decode (base64_decode_haswell, base64_decoder_size_haswell,
                   base64_decoder_init_haswell);
    }

  if (__builtin_cpu_supports ("ssse3"))
    {
      test_encode (base64_encode_core2);
    }

  test_encode (base64_encode_generic);
  test_decode (base64_decode_generic, base64_decoder_size_generic,
               base64_decoder_init_generic);

  return test_exit_status;
}
