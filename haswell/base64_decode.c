/*
 * Decodes Base64 data.
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
#include "base64_decode.h"
#include "base64.h"

#include <stddef.h>
#include <string.h>

size_t
base64_decoder_size_haswell (void)
{
  return BASE64_MAX_DECODER_SIZE;
}

void
base64_decoder_init_haswell (struct base64_decoder *restrict ctx)
{
  ctx->buffer_size = BASE64_MAX_DECODER_SIZE - sizeof (struct base64_decoder);
  ctx->leftovers = 0;
}

bool
base64_decode_haswell (struct base64_decoder *restrict ctx,
                       const char *restrict in, size_t inlen,
                       char *restrict out, size_t *restrict outlen)
{
  if (ctx)
    {
      size_t buffer_size = ctx->buffer_size;
      size_t input_remaining = inlen;
      size_t output_remaining = *outlen;

      while (input_remaining > 0)
        {
          size_t input_to_process = buffer_size - ctx->leftovers;
          input_to_process = input_to_process < input_remaining
                                 ? input_to_process
                                 : input_remaining;

          size_t block_size = base64_denewline_haswell (
              ctx->buffer + ctx->leftovers, in, input_to_process);
          block_size += ctx->leftovers;

          size_t block_processed = block_size;
          size_t block_outputted = output_remaining;

          // decode
          switch (base64_decode_main_haswell (ctx->buffer, &block_processed,
                                              out, &block_outputted))
            {
            case BASE64_DECODE_OK:
              ctx->leftovers = 0;
              break;

            case BASE64_DECODE_INCOMPLETE_INPUT:
              ctx->leftovers = block_size - block_processed;
              memmove (ctx->buffer, ctx->buffer + block_processed, 4);
              break;

            case BASE64_DECODE_TRUNCATED_OUTPUT:
              ctx->leftovers = 0;
              output_remaining -= block_outputted;
              *outlen -= output_remaining;
              return true;

            case BASE64_DECODE_REJECTED:
              ctx->leftovers = 0;
              output_remaining -= block_outputted;
              *outlen -= output_remaining;
              return false;
            }

          in += input_to_process;
          input_remaining -= input_to_process;
          out += block_outputted;
          output_remaining -= block_outputted;
        }

      *outlen -= output_remaining;
      return true;
    }
  else
    {
      // Without a decoder object, decode the simple way. Newlines
      // and non-multiple-of-4-bytes inputs are considered errors.
      size_t remaining = inlen;
      int result = base64_decode_main_haswell (in, &remaining, out, outlen);
      return result == BASE64_DECODE_OK
             || result == BASE64_DECODE_TRUNCATED_OUTPUT;
    }
}
