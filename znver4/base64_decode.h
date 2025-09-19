/*
 * Internal routines used by the Base64 decoder.
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
#ifndef BASE64_DECODE_ZNVER4_H
#define BASE64_DECODE_ZNVER4_H

#ifndef __ASSEMBLER__
#include <stdbool.h>
#include <stddef.h>

/*
 * Decodes a Base64 buffer.
 *
 * inlen and outlen should point to the number of characters in the
 * input and the size of the output buffer respectively; on return,
 * these are overwritten with respectively the number of characters
 * processed and the number of output bytes written.
 *
 * This function returns a status code:
 *
 *   - BASE64_DECODE_OK: The input buffer is fully decoded.
 *   - BASE64_DECODE_TRUNCATED_INPUT: The input buffer size is not a
 *     multiple of 4 bytes, and the trailing bytes are not decoded.
 *   - BASE64_DECODE_TRUNCATED_OUTPUT: The output buffer cannot hold
 *     the full decoded output.
 *   - BASE64_DECODE_REJECTED: The input contains illegal characters.
 *
 * This function rejects input with newlines, namely CR and LF.
 * Call another function beforehand to handle such inputs.
 */
int base64_decode_main_znver4 (const char *restrict in, size_t *restrict inlen,
                               char *restrict out, size_t *restrict outlen);
#endif /* !__ASSEMBLER__ */

#define BASE64_DECODE_OK 0
#define BASE64_DECODE_INCOMPLETE_INPUT 1
#define BASE64_DECODE_TRUNCATED_OUTPUT 2
#define BASE64_DECODE_REJECTED 3

#ifndef __ASSEMBLER__
/*
 * Removes newlines (\r and \n) from the first `size` bytes of `src`.
 * Returns the number of bytes in the output.
 *
 * `dst` must be no smaller than `size`.
 */
size_t base64_denewline_znver4 (char *restrict dst, const char *restrict src,
                                size_t size);

struct base64_decoder
{
  /* Size of the decoding buffer. */
  size_t buffer_size;
  /* Number of undecoded bytes left in buffer. */
  size_t leftovers;
  char buffer[];
};
#endif /* !__ASSEMBLER__ */

#endif /* !BASE64_DECODE_ZNVER4_H */
