/*
 * Fast Base64 encoding for ARMv8-A processors using Neon.
 * Copyright (C) 2025 Du Yijie.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public * License as
 * published by the Free Software Foundation; either version 2.1 of the
 * License, or (at your option) any later version.
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
/* Based on techniques from <https://doi.org/10.1145/3132709>. */
#include "ifunc.h"
#include <arm_neon.h>
#include <stdalign.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

static const alignas (poly128_t) uint8_t shuffle_mask[] = {
  1, 0, 2, 1, 4, 3, 5, 4, 7, 6, 8, 7, 10, 9, 11, 10,
};

static const alignas (uint8x16_t) uint8_t chars[64]
    = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static const alignas (uint8x16_t) uint8_t chars_url[64]
    = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

static void
encode (const char *restrict in, size_t inlen, char *restrict out,
        size_t outlen, const uint8_t *chars)
{
  size_t out_remaining = outlen;

  // bulk encode
  int i;
  for (i = 0; i + 16 <= inlen; i += 12)
    {
      // convert
      uint8x16_t block = vld1q_u8 ((const unsigned char *)&in[i]);
      block = vqtbl1q_u8 (block, (uint8x16_t)vld1q_u8 (shuffle_mask));

      uint16x8_t unit02 = vandq_u16 (block, vdupq_n_u32 (0x0fc0fc00));
      uint16x8_t unit13 = vandq_u16 (block, vdupq_n_u32 (0x003f03f0));
      unit02 = vshlq_u16 (unit02, vdupq_n_u32 (0xfffafff6));
      unit13 = vshlq_u16 (unit13, vdupq_n_u32 (0x00080004));
      block = vorrq_u8 (unit02, unit13);

      block = vqtbl4q_u8 (vld1q_u8_x4 (chars), block);

      // output
      if (out_remaining < 16)
        {
          uint8_t tmp[16];
          vst1q_u8 (tmp, block);
          memcpy (out, tmp, out_remaining);
          return;
        }
      else
        {
          vst1q_u8 ((unsigned char *)out, block);
          out += 16;
          out_remaining -= 16;
        }
    }

  // process the rest with scalar code
  uint8_t ingroup[3];
  uint8_t outgroup[4];
  for (; i + 3 <= inlen && out_remaining > 0; i += 3)
    {
      memcpy (ingroup, &in[i], 3);
      outgroup[0] = chars[(ingroup[0] & 0xfc) >> 2];
      outgroup[1]
          = chars[((ingroup[0] & 0x3) << 4) | ((ingroup[1] & 0xf0) >> 4)];
      outgroup[2]
          = chars[((ingroup[1] & 0xf) << 2) | ((ingroup[2] & 0xc0) >> 6)];
      outgroup[3] = chars[ingroup[2] & 0x3f];

      int outcount = out_remaining < 4 ? out_remaining : 4;
      memcpy (out, outgroup, outcount);
      out += 4;
      out_remaining -= outcount;
    }

  if (i < inlen && out_remaining > 0)
    {
      ingroup[0] = in[i];
      ingroup[1] = (i + 1 < inlen) ? in[i + 1] : 0;
      ingroup[2] = (i + 2 < inlen) ? in[i + 2] : 0;
      outgroup[0] = chars[(ingroup[0] & 0xfc) >> 2];
      outgroup[1]
          = chars[((ingroup[0] & 0x3) << 4) | ((ingroup[1] & 0xf0) >> 4)];
      outgroup[2]
          = (i + 1 < inlen)
                ? chars[((ingroup[1] & 0xf) << 2) | ((ingroup[2] & 0xc0) >> 6)]
                : '=';
      outgroup[3] = (i + 2 < inlen) ? chars[ingroup[2] & 0x3f] : '=';

      int outcount = out_remaining < 4 ? out_remaining : 4;
      memcpy (out, outgroup, outcount);
      out += 4;
      out_remaining -= outcount;
    }

  if (out_remaining > 0)
    *out = 0;
}

void
base64_encode_aarch64 (const char *restrict in, size_t inlen,
                       char *restrict out, size_t outlen)
{
  return encode (in, inlen, out, outlen, chars);
}

void
base64url_encode_aarch64 (const char *restrict in, size_t inlen,
                          char *restrict out, size_t outlen)
{
  return encode (in, inlen, out, outlen, chars_url);
}
