/*
 * Command line Base64 encoder.
 * Copyright (C) 2025 Du Yijie.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, see <https://www.gnu.org/licenses/>.
 */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include "base64.h"

#include <getopt.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "config.h"
#include "version.h"

#define BATCH_SIZE 16384

static const char opts[] = "Vdho:w:";
static const struct option longopts[] = {
  { "decode", no_argument, NULL, 'd' },
  { "help", no_argument, NULL, 'h' },
  { "output", required_argument, NULL, 'o' },
  { "version", no_argument, NULL, 'V' },
  { "wrap", required_argument, NULL, 'w' },
  { 0 },
};

static int
encode (const char *program, FILE *restrict infile, FILE *restrict outfile,
        long wrap)
{
  char (*buf)[BATCH_SIZE] = malloc (2 * BATCH_SIZE);
  char *inbuf = buf[0];
  char *outbuf = buf[1];

  if (!buf)
    {
      fprintf (stderr, "%s: out of memory\n", program);
      return 1;
    }

  size_t lines_per_batch;
  size_t output_per_batch = BATCH_SIZE;

  if (wrap > 0)
    {
      lines_per_batch = BATCH_SIZE / wrap;

      // ensure (lines_per_batch * linewrap) is a multiple of 4 here so
      // that things are easier
      if ((lines_per_batch * wrap) % 4 != 0)
        {
          lines_per_batch -= lines_per_batch % 4;
        }

      output_per_batch = lines_per_batch * wrap;
    }

  size_t input_per_batch = (output_per_batch / 4) * 3;

  while (1)
    {
      size_t incount = fread (inbuf, 1, input_per_batch, infile);

      base64_encode (inbuf, incount, outbuf, BATCH_SIZE);

      // locking outfile outside to reduce overhead
      flockfile (outfile);
      if (wrap > 0)
        {
          for (int i = 0; i < output_per_batch; i += wrap)
            {
              int len = strnlen (&outbuf[i], wrap);
              if (len == 0)
                break;

              fwrite_unlocked (&outbuf[i], 1, len, outfile);
              fputc_unlocked ('\n', outfile);
              if (len < wrap)
                break;
            }
        }
      else
        {
          int len = strnlen (outbuf, BATCH_SIZE);
          fwrite_unlocked (outbuf, 1, len, outfile);
        }
      funlockfile (outfile);

      if (incount < input_per_batch)
        break;
    }

  free (buf);
  return 0;
}

static int
decode (const char *program, FILE *restrict infile, const char *inpath,
        FILE *restrict outfile)
{
  char (*buf)[BATCH_SIZE] = malloc (2 * BATCH_SIZE);
  char *inbuf = buf[0];
  char *outbuf = buf[1];
  struct base64_decoder *decoder = malloc (base64_decoder_size ());

  if (!buf || !decoder)
    {
      free (buf);
      free (decoder);
      fprintf (stderr, "%s: out of memory\n", program);
      return 1;
    }

  base64_decoder_init (decoder);

  while (1)
    {
      size_t incount = fread (inbuf, 1, BATCH_SIZE, infile);
      if (incount == 0)
        break;

      size_t outcount = BATCH_SIZE;
      if (!base64_decode (decoder, inbuf, incount, outbuf, &outcount))
        {
          fwrite (outbuf, 1, outcount, outfile);
          fflush (outfile);
          fprintf (stderr, "%s: invalid input\n", inpath);
          free (buf);
          free (decoder);
          return 1;
        }
      fwrite (outbuf, 1, outcount, outfile);
    }

  free (buf);
  free (decoder);
  return 0;
}

static void
help (const char *program)
{
  printf ("Usage: %s [OPTION]... [FILE]\n"
          "Base64 encode or decode a file, or standard input, to standard "
          "output.\n"
          "\n"
          "With no FILE, or if FILE is -, reads standard input.\n"
          "\n"
          "  -d, --decode         decode data\n"
          "  -o, --output=<FILE>  output encoded or decoded data to <FILE>\n"
          "  -h, --help           display this help and exit\n"
          "  -v, --version        output version information and exit\n"
          "\n"
          "Report any bugs to <%s>.\n",
          program, ISSUE_URL);
}

static void
version (void)
{
  printf ("basse %s\n"
          "Copyright (C) 2025 Du Yijie.\n"
          "This program is free software; you are free to change and\n"
          "redistribute it under GNU GPL, version 3 or later. This program\n"
          "comes with NO WARRANTY, to the extent permitted by law. See\n"
          "<https://gnu.org/licenses/gpl.html> for more details.\n",
          BASSE_VERSION);
}

int
main (int argc, char **argv)
{
  const char *inpath = NULL;
  const char *outpath = NULL;
  int decodemode = false;
  long wrap = 76;

  int option;
  while ((option = getopt_long (argc, argv, opts, longopts, NULL)) != -1)
    {
      switch (option)
        {
        case 'h':
          help (argv[0]);
          exit (0);
        case 'V':
          version ();
          exit (0);
        case 'd':
          decodemode = true;
          break;
        case 'o':
          outpath = optarg;
          break;
        case 'w':
          {
            char *end;
            wrap = strtol (optarg, &end, 0);
            if (*end != 0)
              {
                fprintf (stderr,
                         "%s: argument to -w or --wrap must be a number\n"
                         "Try '%s --help' for more information.\n",
                         argv[0], argv[0]);
                exit (1);
              }
          }
        case '?':
          fprintf (stderr, "Try '%s --help' for more information.\n", argv[0]);
          exit (1);
        }
    }

  if (argc > optind)
    {
      if (strcmp (argv[optind], "-") != 0)
        inpath = argv[optind];
    }

  FILE *infile = stdin;
  FILE *outfile = stdout;

  if (inpath)
    {
      // let us handle differing newlines instead
      infile = fopen (inpath, "rb");
      if (!infile)
        {
          fprintf (stderr, "%s: cannot open input file %s\n", argv[0], inpath);
          exit (1);
        }
    }

  if (outpath)
    {
      outfile = fopen (outpath, decodemode ? "wb" : "w");
      if (!outfile)
        {
          fprintf (stderr, "%s: cannot open output file %s\n", argv[0],
                   outpath);
          exit (1);
        }
    }

  if (decodemode)
    {
      exit (decode (argv[0], infile, inpath ?: "<stdin>", outfile));
    }
  else
    {
      exit (encode (argv[0], infile, outfile, wrap));
    }
}
