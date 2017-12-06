#!/usr/bin/env python

import libarchive

sources = {'win': {'url': 'https://go.microsoft.com/fwlink/?linkid=852724',
                    'fn': 'SRO_3.4.1.0_1033.cab',
                   'sha': 'cb2632c339ae5211cb3475bf33b8ad9c3159f410c11d34ffca85d0527f872985'},
           'mac': {'url': 'https://mran.blob.core.windows.net/install/mro/3.4.1/microsoft-r-open-3.4.1.pkg',
                    'fn': 'microsoft-r-open-3.4.1.pkg',
                   'sha': '643c5e953a02163ae73273da27f9c1752180f55bf836b127b6e1829fd1756fc8'}}

HEADER='''
{% set pfx = 'r-' %}
{% set version = '3.4.1' %}

{% set url = '{win_url}' %}  # [win64]
{% set fn = '{win_fn}' %}  # [win64]
{% set shasum = '{win_sha}' %}  # [win64]

{% set url = '{mac_url}' %}  # [osx]
{% set fn = '{mac_fn}' %}  # [osx]
{% set shasum = '{mac_sha}' %}  # [osx]

package:
  name: r
  version: {{ version }}

source:
  fn: {{ fn }}
  url: {{ url }}
  sha256: {{ shasum }}

requirements:
  build:
    - python-libarchive-c
'''

# These are the packages that should be in r-base. Any folders in 'library' that are not in
# this list need to be made into separate packages.
officially_bundled_packages = ('base', 'compiler', 'datasets', 'graphics', 'grDevices',
                               'grid', 'methods', 'parallel', 'splines', 'stats', 'stats4',
                               'tcltk', 'tools', 'translations', 'utils')

def main():
    print(HEADER.format(win_url=sources['win']['url'],
                        win_fn=sources['win']['fn'],
                        win_sha=sources['win']['sha'],
                        mac_url=sources['mac']['url'],
                        mac_fn=sources['mac']['fn'],
                        mac_sha=sources['mac']['sha']))

if __name__ == '__main__':
  main()
