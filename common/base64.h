/*
 * Base64 encoding API.
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
#ifndef BASE64_H
#define BASE64_H

#ifdef __cplusplus
extern "C"
{
#endif

#include <stdbool.h>
#include <stddef.h>

#define BASE64_MAX_DECODER_SIZE 16384

extern void base64_encode (const char *restrict in, size_t inlen,
                           char *restrict out, size_t outlen);

struct base64_decoder;

extern size_t base64_decoder_size ();
extern void base64_decoder_init (struct base64_decoder *);
extern bool base64_decode (struct base64_decoder *restrict,
                           const char *restrict in, size_t inlen,
                           char *restrict out, size_t *restrict outlen);

#ifdef __cplusplus
}
#endif

#endif
