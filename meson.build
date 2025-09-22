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
project(
    'basse',
    'c',
    version: '0.1.0',
    meson_version: '>=1.0.0',
    default_options: ['c_std=gnu23']
)

if host_machine.system() != 'linux'
    error('unsupported operating system')
endif

cfg = configuration_data()
cfg.set('issue_url', get_option('basse_issue_url'))
configure_file(
    input: 'config.h.in',
    output: 'config.h',
    configuration: cfg,
)

config_include = include_directories('.')

subdir('scripts')

lib_src = []

subdir('common')
subdir('generic')

if host_machine.cpu_family() == 'x86_64'
    subdir('core2')
    subdir('nehalem')
    subdir('haswell')
    subdir('znver4')
elif host_machine.cpu_family() == 'aarch64'
    subdir('aarch64')
endif

lib = library('basse',
    lib_src,
    version: '1.0',
    include_directories: [include, config_include],
    install: true
)
lib_dep = declare_dependency(link_with: lib, include_directories: include)

subdir('program')
subdir('doc')
subdir('tests')
