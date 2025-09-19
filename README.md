# basse
`basse` (/beɪs/) is a blazingly fast Base64 encoder and decoder using SIMD
technology. `libbasse` is the Base64 encoding and decoding library powering
`basse`.

## Building
Build prerequisites:

  - Linux. Could also build on some BSDs &ndash; modify the root
    `meson.build` to see for sure. You need to count on WSL if
    you use Windows.
  - A C11 compiler. [GCC] and [Clang] are preferred.
  - [Meson] 1.0.0 or later.

To build:

```console
$ meson setup build
$ cd build
$ ninja
```

To run tests:

```console
$ cd build
$ ninja test
```

To install:

```console
$ cd build
$ ninja install
```

## Usage
The usage of `basse` is similar to GNU `base64`. To encode a file to Base64:

```console
$ basse path/to/input
```

To decode Base64 data:

```console
$ basse -d -o path/to/output path/to/input
```

See the man pages for further details on `basse`, and for usage of `libbasse`.

## Processor support
Optimized Base64 encoding is available on the following processors:

  - Intel&reg; Core&trade; 2 Duo and better, using SSSE3
  - Intel&reg; Core&trade; i3-4120 and better, using AVX2
  - AMD&reg; Ryzen&trade; 5 7600X and better, using AVX512

Optimized Base64 decoding is available on the following processors:

  - Intel&reg; Core&trade; i3-4120 and better, using AVX2
  - AMD&reg; Ryzen&trade; 5 7600X and better, using AVX512

On all other processors, portable code identical to that used in GNU
coreutils is used.

## Acknowledgements
This program is based on the algorithms outlined in [Faster Base64 Encoding
and Decoding Using AVX2 Instructions](https://doi.org/10.1145/3132709).

The handling of newlines in the Base64 decoding process is based on the
process outlined in [Daniel Lemire]'s blog post, ["How quickly can you
remove spaces from a string?"][prunespace]

The portable Base64 encoding and decoding implementations and the unit
test facilities comes from [Gnulib], part of the GNU Project. They are
written by Simon Josefsson.

## License

Copyright &copy; 2025 Du Yijie.

basse, and the unit tests of libbasse, are licensed under the GNU General
Public License, version 3, or any later version.

libbasse is licensed under the GNU Lesser General Public License, version
2.1, or any later version.

The documentation and manual pages associated with basse and libbasse are
licensed under the GNU Free Documentation License, version 1.3 or any
later version.

THERE IS NO WARRANTY FOR BASSE AND LIBBASSE. THE COPYRIGHT HOLDER IS NOT
LIABLE FOR ANY DAMAGES ARISING FROM THE USE OF BASSE AND LIBBASSE.

See COPYING, COPYING.LGPL and COPYING.GFDL for further details.

[GCC]: https://gcc.gnu.org/
[Clang]: https://clang.llvm.org/
[Meson]: https://mesonbuild.com/
[Daniel Lemire]: https://lemire.me/en/
[prunespace]: https://lemire.me/blog/2017/01/20/how-quickly-can-you-remove-spaces-from-a-string/
[Gnulib]: https://www.gnu.org/software/gnulib/
