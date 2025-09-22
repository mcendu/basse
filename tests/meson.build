# Copyright (C) 2025 Du Yijie.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <https://www.gnu.org/licenses/>.

test(
    'test_basic',
    executable('test_basic', 'test_basic.c', dependencies: lib_dep)
)

test(
    'test_long',
    executable('test_long', 'test_long.c', dependencies: lib_dep)
)

test(
    'doctests',
    find_program('perl'),
    args: [find_program('./doctests.pl').full_path()],
    depends: [
        executable('test_encode_doc', 'test_encode_doc.c',
                   dependencies: lib_dep),
        executable('test_decode_doc', 'test_decode_doc.c',
                   dependencies: lib_dep),
        executable('test_decode_static_doc', 'test_decode_static_doc.c',
                   dependencies: lib_dep)
    ],
    workdir: meson.current_build_dir(),
)
