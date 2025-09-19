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
version_h = vcs_tag(
    input: 'version.h.in',
    output: 'version.h',
)

bin_src = files(
    'main.c',
)

executable(
    'basse',
    bin_src,
    version_h,
    dependencies: [lib_dep],
    include_directories: config_include,
    install: true
)
