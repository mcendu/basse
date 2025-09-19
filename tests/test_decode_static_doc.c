/*
 * This is free and unencumbered software released into the public domain.
 *
 * Anyone is free to copy, modify, publish, use, compile, sell, or
 * distribute this software, either in source code form or as a compiled
 * binary, for any purpose, commercial or non-commercial, and by any
 * means.
 *
 * In jurisdictions that recognize copyright laws, the author or authors
 * of this software dedicate any and all copyright interest in the
 * software to the public domain. We make this dedication for the benefit
 * of the public at large and to the detriment of our heirs and
 * successors. We intend this dedication to be an overt act of
 * relinquishment in perpetuity of all present and future rights to this
 * software under copyright law.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * For more information, please refer to <https://unlicense.org>
 */
/* This is an example program from the manual page of base64_decode(). */
#include <base64.h>
#include <stdalign.h>
#include <stdio.h>
#include <string.h>

int
main (void)
{
  static const char in[] = "aGVsbG8sIHdvcmxkCg==";
  char buf[16];

  /* Because `struct base64_decoder` is opaque, you cannot
   *      directly create one statically. You should create a
   *      `BASE64_MAX_DECODER_SIZE`-sized buffer with `size_t`
   *      alignment, create a pointer to it, then cast the
   *      pointer to the right type. */
  static alignas (size_t) char dbuf[BASE64_MAX_DECODER_SIZE];
  struct base64_decoder *dec = (struct base64_decoder *)dbuf;
  base64_decoder_init (dec);

  size_t outlen = sizeof (buf);
  base64_decode (dec, in, strlen (in), buf, &outlen);
  printf ("%.*s", (int)outlen, buf);
  return 0;
}
