#!/usr/bin/env python

import hashlib
import libarchive
import os
import re
import sys
import tarfile
import unicodedata
import yaml
# try to import C dumper
try:
    from yaml import CSafeDumper as SafeDumper
except ImportError:
    from yaml import SafeDumper

import distutils
from distutils import dir_util
from itertools import chain

from conda_build.conda_interface import text_type, iteritems
from conda_build.config import Config
from conda_build.skeletons.cran import (dict_from_cran_lines, remove_package_line_continuations)
from conda_build.skeletons.cran import R_BASE_PACKAGE_NAMES as R_BASE_PACKAGE_NAMES_ORIG
from conda_build.source import download_to_cache
from conda_build.license_family import allowed_license_families, guess_license_family

from tempfile import TemporaryDirectory

VERSION = '3.4.3'
INDENT = '\n        - '

# The following base/recommended package names are derived from R's source
# tree (R-3.0.2/share/make/vars.mk).  Hopefully they don't change too much
# between versions.

R_BASE_PACKAGE_NAMES = R_BASE_PACKAGE_NAMES_ORIG + ('translations', 'RevoUtils')

# Stolen then tweaked from debian.deb822.PkgRelation.__dep_RE.
VERSION_DEPENDENCY_REGEX = re.compile(
    r'^\s*(?P<name>[a-zA-Z0-9.+\-]{1,})'
    r'(\s*\(\s*(?P<relop>[>=<]+)\s*'
    r'(?P<version>[0-9a-zA-Z:\-+~.]+)\s*\))'
    r'?(\s*\[(?P<archs>[\s!\w\-]+)\])?\s*$'
)

extra_deps = { 'r-deployrrserve': [INDENT + 'libstdcxx-ng >=7.2.0  # [linux]', INDENT + 'libgcc-ng >=7.2.0  # [linux]'],
               'r-revoutilsmath': [INDENT + 'libgcc-ng >=7.2.0  # [linux]'],
               'r-mgcv': [INDENT + 'libgcc-ng >=7.2.0  # [linux]'],
               'mro-base': [INDENT + 'libgfortran >=3.0.1  # [osx]']}

sources = {
           'win': {      'url': 'https://mran.blob.core.windows.net/install/mro/'+VERSION+'/microsoft-r-open-'+VERSION+'.exe',
                          'fn': 'microsoft-r-open-'+VERSION+'.exe',
                         'sha': 'c8d50172ec8173cef503a616f9ef310dc5b274ac045ea71b9c8aed248098cbdd',  # 3.4.3
#                        'sha': '6ee89d8642d3a153e5c4295e5028b6e70f657b1768b10e23cb5d7da8a9c7552d',  # 3.4.2
#                        'sha': '04f7be3aaf393937b2edb536f1a3c7f279145b3aeb6e5eefdf9bee1ac137afc6',  # 3.4.1
                     'library': 'library'},
# This does not contain MKL:
#           'win': {      'url': 'https://go.microsoft.com/fwlink/?linkid=852724',
#                          'fn': 'SRO_'+VERSION+'.0_1033.cab',
#                         'sha': 'cb2632c339ae5211cb3475bf33b8ad9c3159f410c11d34ffca85d0527f872985',
#                     'library': 'library'},
           'linux': {    'url': 'https://mran.blob.core.windows.net/install/mro/'+VERSION+'/microsoft-r-open-'+VERSION+'.tar.gz',
                          'fn': 'microsoft-r-open-'+VERSION+'.tar.gz',
                         'sha': 'bf2cd35a11db604b1fa8f5f0c0acf0ae05756020d90fb3f6cbb639337efcee5b',  # 3.4.3
#                        'sha': 'edc783e42911f182c52d1e8623b979042b090295e221bbd2eb9b47a7fb9c8cd3',  # 3.4.2
#                        'sha': '83c2f36f255483e49cefa91a143c020ad9dfdfd70a101432f1eae066825261cb',  # 3.4.1
                     'library': 'opt/microsoft/ropen/'+VERSION+'/lib64/R/library'},
           'mac': {      'url': 'https://mran.blob.core.windows.net/install/mro/'+VERSION+'/microsoft-r-open-'+VERSION+'.pkg',
                          'fn': 'microsoft-r-open-'+VERSION+'.pkg',
                         'sha': '4998500839389821f995d3ebb89ee7e8e5a35a61a63ba0ac54d63adf53288947',  # 3.4.3
#                        'sha': 'f533bcef949162d1036d92e9d12c414a4713c98a81641dee95b7f71717669832',  # 3.4.2
#                        'sha': '643c5e953a02163ae73273da27f9c1752180f55bf836b127b6e1829fd1756fc8',  # 3.4.1
                     'library': 'Library/Frameworks/R.framework/Resources/library'}}

HEADER='''
{{% set pfx = 'r-' %}}
{{% set version = '{version}' %}}

{{% set url = '{win_url}' %}}  # [win64]
{{% set fn = '{win_fn}' %}}  # [win64]
{{% set shasum = '{win_sha}' %}}  # [win64]

{{% set url = '{linux_url}' %}}  # [linux64]
{{% set fn = '{linux_fn}' %}}  # [linux64]
{{% set shasum = '{linux_sha}' %}}  # [linux64]

{{% set url = '{mac_url}' %}}  # [osx]
{{% set fn = '{mac_fn}' %}}  # [osx]
{{% set shasum = '{mac_sha}' %}}  # [osx]

package:
  name: r
  version: {{{{ version }}}}

source:
  - url: {{{{ url }}}}
    fn: {{{{ fn }}}}
    sha256: {{{{ shasum }}}}
    folder: unpack
  - url: https://github.com/wixtoolset/wix3/releases/download/wix311rtm/wix311-binaries.zip  # [win64]
    sha256: da034c489bd1dd6d8e1623675bf5e899f32d74d6d8312f8dd125a084543193de                 # [win64]
    folder: wix                                                                              # [win64]

requirements:
  build:
    - python-libarchive-c
    - posix  # [win]
  host:
    - m2w64-toolchain  # [win]
    - m2-base  # [win]
'''

BASE_PACKAGE='''
outputs:
  - name: mro-base
    version: {{ version }}
    script: install-mro-base.sh
    requirements:
      build:
        - m2-base  # [win]
        - {{ compiler('fortran') }}  # [not win]
        - {{ compiler('cxx') }}  # [not win]
        - {{ compiler('c') }}  # [not win]
      host:
        - libgfortran >=3.0.1  # [osx]
        - llvm-openmp >=4.0.1  # [osx]
        - expat  # [osx]
        - curl  # [osx]
        - libiconv  # [osx]
        - ncurses  # [osx]
      run:
        - {{ compiler('fortran') }}  # [not win]
        - {{ compiler('cxx') }}  # [not win]
        - {{ compiler('c') }}  # [not win]
        - libgfortran >=3.0.1  # [osx]
        - llvm-openmp >=4.0.1  # [osx]
        - curl  # [osx]

  - name: r-base
    version: {{ version }}
    requirements:
      build:
        - {{ pin_subpackage('mro-base', min_pin='x.x.x.x', max_pin='x.x.x.x') }}
      run:
        - {{ pin_subpackage('mro-base', min_pin='x.x.x.x', max_pin='x.x.x.x') }}

'''

PACKAGE='''
  - name: {packagename}
    version: {conda_version}
    script: install-r-package.sh
    # This is required to make R link correctly on Linux.
    build:
{skip}
      rpaths:
        - lib/R/lib/
        - lib/
{always_include_files}
{suggests}
    requirements:
      build:
        - m2-base  # [win]
      host:{run_depends}
      run:{run_depends}

    test:
      commands:
        # You can put additional test commands to be run here.
        - $R -e "library('{cran_packagename}')"           # [not win]
        - "\\"%R%\\" -e \\"library('{cran_packagename}')\\""  # [win]

    about:
      {home_comment}home:{homeurl}
      license: {license}
      {summary_comment}summary:{summary}
      license_family: {license_family}
'''

MRO_BASICS_METAPACKAGE='''
  - name: mro-basics
    version: {{ version }}
    requirements:
      run:
        - mro-base {{ version }}
        - r-base
'''

BUILD_SH='''#!/bin/bash

if [[ $target_platform == win-64 ]]; then
  ARCHIVE={win_fn}
elif [[ $target_platform == linux-64 ]]; then
  ARCHIVE={linux_fn}
elif [[ $target_platform == osx-64 ]]; then
  ARCHIVE={mac_fn}
fi

mkdir -p unpack
pushd unpack

  # 1. Finish unpacking.
  #    (if conda-build used libarchive to unpack things we could aim to remove this
  #     but it would need a metadata flag to unpack archives within archives too).
  declare -a ARCHIVES
  if [[ -f $ARCHIVE ]]; then
    if [[ $target_platform == win-64 ]]; then
      pushd $(mktemp -d)
        chmod +x "$SRC_DIR"/wix/dark.exe
        "$SRC_DIR"/wix/dark.exe $SRC_DIR/unpack/$ARCHIVE -x $PWD
        rm -f $SRC_DIR/unpack/$ARCHIVE
        msiexec -a $(cygpath -w $PWD/AttachedContainer/ROpen.msi) -qb TARGETDIR=$(cygpath -w "$PWD")
        mv Microsoft/MRO-$PKG_VERSION.0/Setup/MKL_2017.0.36.5_1033.cab "$SRC_DIR"/unpack
        mv Microsoft/MRO-$PKG_VERSION.0/Setup/MROPKGS_9.2.0.0_1033.cab "$SRC_DIR"/unpack
        # This contains VCRT_14.0.23026.0_1033.exe and RSetup.exe
        rm -rf Microsoft/MRO-$PKG_VERSION.0/Setup
        mkdir -p "$SRC_DIR"/unpack/lib
        mv Microsoft/MRO-$PKG_VERSION.0 "$SRC_DIR"/unpack/lib/R
        # msiexec -a $(cygpath -w $PWD/Microsoft/MRO-$PKG_VERSION.0/Setup/MKL_2017.0.36.5_1033.cab) -qb TARGETDIR=$(cygpath -w "$SRC_DUR"/unpack)
        # msiexec -a $(cygpath -w $PWD/Microsoft/MRO-$PKG_VERSION.0/Setup/MROPKGS_9.2.0.0_1033.cab) -qb TARGETDIR=$(cygpath -w "$SRC_DUR"/unpack)
        # TODO :: The MKL archive should probably be unpacked when during install-r-package.sh for RevoUtilsMath instead.
        ARCHIVES+=(MKL_2017.0.36.5_1033.cab,lib/R)
        ARCHIVES+=(MROPKGS_9.2.0.0_1033.cab,lib/R)
      popd
    elif [[ $target_platform == osx-64 ]]; then
      # https://github.com/libarchive/libarchive/issues/456
      xar -xf $ARCHIVE
      rm $ARCHIVE
      for PAYLOAD in $(find . -name Payload); do
        ARCHIVES+=($PAYLOAD,.)
      done
    else
      ARCHIVES+=($ARCHIVE,.)
    fi
    echo ARCHIVES are ${{ARCHIVES[@]}}
    for ARCHIVE_DEST in "${{ARCHIVES[@]}}"; do
      ARCHIVE=${{ARCHIVE_DEST//,*/}}
      DEST=${{ARCHIVE_DEST#*,}}
      if [[ "$DEST" != "." ]]; then
        mv $ARCHIVE $DEST/
      fi
      pushd $DEST
        python -c "import libarchive, os; libarchive.extract_file('$ARCHIVE')" || exit 1
        rm $ARCHIVE
      popd
    done
  fi
  if [[ $target_platform == linux-64 ]]; then
    # TODO :: May need to put the MKL libs into a separate package (actually they're in r-revoutilsmath)
    for RPM in $(find rpm -name "*.rpm"); do
      echo $RPM
      python -c "import libarchive, os; libarchive.extract_file('$RPM')" || true
      find .
    done
  fi

  # 2. Save filelist back to the recipe.
  find . | LC_COLLATE=C sort --ignore-case > "$RECIPE_DIR"/filelist-mro-$PKG_VERSION-$target_platform.after-unpacking.txt

  # 3. Rearrange layout so it is compatible with conda, or at least does not stomp all over
  #    conda packages (MKL for example).
  if [[ $target_platform == linux-64 ]]; then
    mv opt/microsoft/ropen/$PKG_VERSION/lib64 lib
    mv opt/microsoft/ropen/$PKG_VERSION/stage stage
  elif [[ $target_platform == osx-64 ]]; then
    FRAMEWORK=/Library/Frameworks/R.framework
    RESOURCES=$FRAMEWORK/Versions/$PKG_VERSION-MRO/Resources
    mkdir -p lib/R
    mv .$RESOURCES/lib lib/R/
    mv .$RESOURCES/bin lib/R/
    mv .$RESOURCES/etc lib/R/
    mv .$RESOURCES/include lib/R/
    mv .$RESOURCES/library lib/R/
    mv .$RESOURCES/modules lib/R/
    # Get rid of all MS-provided clang compiler runtime DSOs
    rm lib/R/lib/libc++.1.dylib
    rm lib/R/lib/libc++abi.1.dylib
    rm lib/R/lib/libunwind.1.dylib
    rm lib/R/lib/libomp.dylib
    # And all of the MS-provided GCC compiler runtime DSOs
    rm lib/R/lib/libgfortran.3.dylib
    rm lib/R/lib/libquadmath.0.dylib
    rm lib/R/lib/libgcc_s.1.dylib
  else
    echo "No layout necessary for $target_platform"
  fi

  # 4. Implement any necessary fixes.
  if [[ $target_platform == linux-64 ]]; then
    # Workaround: https://github.com/Microsoft/microsoft-r-open/issues/15
    #        and: https://github.com/Microsoft/microsoft-r-open/issues/44
    pushd $(mktemp -d)
      curl -SLO http://vault.centos.org/5.11/os/x86_64/CentOS/libpng-1.2.10-17.el5_8.x86_64.rpm
      "$RECIPE_DIR"/rpm2cpio libpng-1.2.10-17.el5_8.x86_64.rpm | cpio -idmv
      cp -p usr/lib64/libpng12.so.0* "$SRC_DIR"/unpack/lib/R/modules/
    popd
    patchelf --set-rpath '$ORIGIN' lib/R/modules/R_X11.so
    # Prevent the MRO MKL libraries from stomping over the files in Anaconda Distribution's MKL package.
    mkdir -p lib/R/lib/mro_mkl/
    mv stage/Linux/bin/x64/* lib/R/lib/mro_mkl/
    OLD_RPATH=$(patchelf --print-rpath lib/R/library/RevoUtilsMath/libs/RevoUtilsMath.so)
    patchelf --set-rpath '$ORIGIN'/../../../lib/mro_mkl:$OLD_RPATH lib/R/library/RevoUtilsMath/libs/RevoUtilsMath.so
  elif [[ $target_platform == osx-64 ]]; then
    mkdir -p sysroot/usr/lib/
    cp /usr/lib/libicucore.A.dylib sysroot/usr/lib/
    cp /usr/lib/libncurses.5.4.dylib sysroot/usr/lib/
    cp /usr/lib/libiconv.2.dylib sysroot/usr/lib/
    chmod u+w sysroot/usr/lib/*
    declare -a DYLIBS
    for DYLIB in $(find . -type f -iname "*.dylib" -or -iname "*.so"); do
      DYLIBS+=($DYLIB)
      install_name_tool -id $(basename $DYLIB) $DYLIB
    done
    echo "DYLIBS are:"
    for DYLIB in ${{DYLIBS[@]}}; do
      echo $DYLIB
    done
    sed -i'.bak' "s|$FRAMEWORK/Resources|$PREFIX/lib/R|g" lib/R/bin/R
    rm lib/R/bin/R.bak
    # Use conda's compilers
    sed -i'.bak' "s|/usr/local/clang4|$PREFIX|g" lib/R/etc/Makeconf
    sed -i'.bak' "s|/usr/local/gfortran|$PREFIX|g" lib/R/etc/Makeconf
    sed -i'.bak' "s|/usr/local/gfortran/lib/gcc/x86_64-apple-darwin15/6.1.0|$PREFIX/lib/gcc/x86_64-apple-darwin11.4.2/4.8.5|g" lib/R/etc/Makeconf
    sed -i.'bak' "s|-F/Library/Frameworks/R.framework/.. -framework R|-L$PREFIX/lib/R/lib -lR|g" lib/R/etc/Makeconf
    rm lib/R/etc/Makeconf.bak
    # Others things to fix in: lib/R/etc/Makeconf
    # JAVA_HOME = /Library/Java/JavaVirtualMachines/jdk1.8.0_144.jdk/Contents/Home/jre
    # LIBR = -F/Library/Frameworks/R.framework/.. -framework R
    # Fix the LC_LOAD_DYLIB entries:
    for libdir in lib/R/lib lib/R/modules lib/R/library lib/R/bin/exec sysroot/usr/lib; do
      pushd $libdir || exit 1
      echo "Pushed to libdir $libdir"
        for SHARED_LIB in $(find . -type f -iname "*.dylib" -or -iname "*.so" -or -iname "R"); do
          echo "fixing SHARED_LIB $SHARED_LIB"
          install_name_tool -change /Library/Frameworks/R.framework/Versions/3.4.3-MRO/Resources/lib/libR.dylib "$PREFIX"/lib/R/lib/libR.dylib $SHARED_LIB || true
          install_name_tool -change /usr/local/clang4/lib/libomp.dylib "$PREFIX"/lib/libomp.dylib $SHARED_LIB || true
          install_name_tool -change /usr/local/gfortran/lib/libgfortran.3.dylib "$PREFIX"/lib/libgfortran.3.dylib $SHARED_LIB || true
          install_name_tool -change /usr/local/gfortran/lib/libquadmath.0.dylib "$PREFIX"/lib/libquadmath.0.dylib $SHARED_LIB || true
          install_name_tool -change /usr/lib/libgcc_s.1.dylib "$PREFIX"/lib/libgcc_s.1.dylib $SHARED_LIB || true
          install_name_tool -change /usr/lib/libiconv.2.dylib "$PREFIX"/sysroot/usr/lib/libiconv.2.dylib $SHARED_LIB || true
          install_name_tool -change /usr/lib/libncurses.5.4.dylib "$PREFIX"/sysroot/usr/lib/libncurses.5.4.dylib $SHARED_LIB || true
          install_name_tool -change /usr/lib/libicucore.A.dylib "$PREFIX"/sysroot/usr/lib/libicucore.A.dylib $SHARED_LIB || true
          install_name_tool -change /usr/lib/libexpat.1.dylib "$PREFIX"/lib/libexpat.1.dylib $SHARED_LIB || true
          install_name_tool -change /usr/lib/libcurl.4.dylib "$PREFIX"/lib/libcurl.4.dylib $SHARED_LIB || true
          install_name_tool -change /usr/lib/libc++.1.dylib "$PREFIX"/lib/libc++.1.dylib $SHARED_LIB || true
        done
      popd
    done
    # One-off fixups. It seems some packages were not rebuilt against R 3.4.3 (doing them for every dylib would be slow):
    install_name_tool -change /Library/Frameworks/R.framework/Versions/3.4.0-MRO/Resources/lib/libR.dylib "$PREFIX"/lib/R/lib/libR.dylib lib/R/library/curl/libs/curl.so || exit 1
    install_name_tool -change /Library/Frameworks/R.framework/Versions/3.4.0-MRO/Resources/lib/libR.dylib "$PREFIX"/lib/R/lib/libR.dylib lib/R/library/jsonlite/libs/jsonlite.so || exit 1
    install_name_tool -change /Library/Frameworks/R.framework/Versions/3.4.0-MRO/Resources/lib/libR.dylib "$PREFIX"/lib/R/lib/libR.dylib lib/R/library/png/libs/png.so || exit 1
  else
    echo "No fixes necessary for $target_platform"
  fi
popd

# 6. Compile launcher stub.
if [[ $target_platform == win-64 ]]; then
  # Compile the launcher
  # XXX: Should we build Rgui with -DGUI=1 -mwindows?  The only difference is
  # that it does not block the terminal, but we also cannot get the return
  # value for the conda build tests.
  # NOTE: This needs to be run on Windows or via Wine.
  if [[ ! $(uname) =~ M* ]]; then
    WINE=wine
    if ! which $WINE; then
      echo "To build mro-base on $BUILD you need Wine"
      exit 1
    fi
  fi
  # Wine has trouble finding DLLs on PATH?!
  pushd "$PREFIX"/Library/mingw-w64/bin
    PATH="$PREFIX"/Library/mingw-w64/bin:$PATH \\
      $WINE "$PREFIX"/Library/mingw-w64/bin/gcc.exe -DGUI=0 -O -s -o "$SRC_DIR"/launcher.exe "$RECIPE_DIR"/launcher.c || exit 1
  popd
fi

# 7. Save end of build.sh filelist back to the recipe.
pushd unpack
  find . | LC_COLLATE=C sort --ignore-case > "$RECIPE_DIR"/filelist-mro-$PKG_VERSION-$target_platform.end-of-build-sh.txt
popd
'''

INSTALL_MRO_BASE_HEADER='''#!/bin/bash

# activate the build environment
. activate "$BUILD_PREFIX"

contains () {{
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}}

make_mro_base () {{
  LIBRARY=/lib/R/library
  PREFIX_LIB="$PREFIX"/lib/R/library
  if [[ $target_platform == win-64 ]]; then
    # Install the launcher
    mkdir -p "$PREFIX"/Scripts
    cp launcher.exe $PREFIX/Scripts/R.exe
    cp launcher.exe $PREFIX/Scripts/Rcmd.exe
    cp launcher.exe $PREFIX/Scripts/RSetReg.exe
    cp launcher.exe $PREFIX/Scripts/Rfe.exe
    cp launcher.exe $PREFIX/Scripts/Rgui.exe
    cp launcher.exe $PREFIX/Scripts/Rscript.exe
    cp launcher.exe $PREFIX/Scripts/Rterm.exe
    cp launcher.exe $PREFIX/Scripts/open.exe
  fi

  # Make symlinks in PREFIX/bin for Unix platforms.
  if [[ $target_platform != win-64 ]]; then
    declare -a EXES
    pushd unpack/lib/R/bin
      for EXE in $(find . -iname "*" -type f -maxdepth 1 -mindepth 1); do
        EXE=${{EXE//.\//}}
        EXES+=($EXE)
      done
    popd
    pushd $PREFIX/bin
      for EXE in ${{EXES[@]}}; do
        if [[ ! $EXE =~ .*conda_build.sh ]] && [[ ! $EXE =~ .*install-.*.sh ]]; then
          ln -s ../lib/R/bin/$EXE $EXE || exit 1
        fi
      done
    popd
  fi

  # Make symlinks to the Anaconda Distribution compilers on Linux.
  if [[ $target_platform == linux-64 ]]; then
    pushd $PREFIX/bin
      ln -s $HOST-ar ar
      ln -s $HOST-cc cc
      ln -s $HOST-c++ c++
      ln -s $HOST-gcc gcc
      ln -s $HOST-g++ g++
      ln -s $HOST-gfortran fc
      ln -s $HOST-gfortran f77
      ln -s $HOST-ranlib ranlib
      ln -s $HOST-strip strip
    popd
  fi

  mkdir -p "$PREFIX_LIB"

  pushd unpack$LIBRARY || exit 1
    for LIBRARY_CASED in $(find . -iname "*" -maxdepth 1 -mindepth 1); do
      LIBRARY_CASED=${{LIBRARY_CASED//.\//}}
      if ! contains $LIBRARY_CASED "${{EXCLUDED_PACKAGES[@]}}"; then
        echo "Including $LIBRARY_CASED => $PREFIX_LIB"
        mv $LIBRARY_CASED "$PREFIX_LIB"/
      else
        echo "Skipping $LIBRARY_CASED"
      fi
    done
  popd

  [[ -d unpack/sysroot ]] && mv unpack/sysroot $PREFIX

  pushd unpack$LIBRARY/.. || exit 1
    mv library ../
    [[ -d lib/mro_mkl ]] && mv lib/mro_mkl ../
    # We have no m2-rsync unfortunately.
    # rsync -avv . "$PREFIX" || exit 1
    cp -rf * "$PREFIX"/lib/R/
    mv ../library .
    [[ -d ../mro_mkl ]] && mv ../mro_mkl lib/
    pushd $PREFIX
      find . | LC_COLLATE=C sort --ignore-case > "$RECIPE_DIR"/filelist-mro-base-$PKG_VERSION-$target_platform.in-prefix.txt
    popd
  popd
}}
declare -a EXCLUDED_PACKAGES
'''

INSTALL_MRO_BASE_FOOTER='''
make_mro_base
'''

INSTALL_R_PACKAGE='''#!/bin/bash

LIBRARY_NAME=${{PKG_NAME//r-/}}

LIBRARY=/lib/R/library
PREFIX_LIB="$PREFIX"/$LIBRARY

mkdir -p "$PREFIX_LIB"

if [[ "$LIBRARY_NAME" == "revoutilsmath" ]] && [[ $target_platform == linux-64 ]]; then
  mkdir -p "$PREFIX"/lib/R/lib/mro_mkl/
  mv unpack/lib/R/lib/mro_mkl/* "$PREFIX"/lib/R/lib/mro_mkl/
  mv "$PREFIX"/lib/R/lib/mro_mkl/libRblas.so "$PREFIX"/lib/R/lib/
fi

pushd unpack$LIBRARY || exit 1
  for LIBRARY_CASED in $(find . -iname "$LIBRARY_NAME" -maxdepth 1 -mindepth 1); do
    if [[ $target_platform == osx-64 ]]; then
      # Un-framework-ification.
      for SHARED_LIB in $(find $LIBRARY_CASED . -iname "*.dylib" -or -iname "*.so"); do
        install_name_tool -change /Library/Frameworks/R.framework/Versions/3.4.3-MRO/Resources/lib/libR.dylib "$PREFIX"/lib/R/lib/libR.dylib $SHARED_LIB || true
        install_name_tool -change /usr/local/clang4/lib/libomp.dylib "$PREFIX"/lib/libomp.dylib $SHARED_LIB || true
      done
    fi
    mv $LIBRARY_CASED "$PREFIX_LIB"/
  done
popd

find . | wc -l
'''

build_and_skip_olw = {(True,  True,  True):  ("", ""),
                      (True,  True,  False): ("  # [osx or linux]",   "      skip: True  # [win]"),
                      (True,  False, True):  ("  # [osx or win]",     "      skip: True  # [linux]"),
                      (False, True,  True):  ("  # [linux or win]",   "      skip: True  # [osx]"),
                      (True,  False, False): ("  # [osx]",            "      skip: True  # [not osx]"),
                      (False, False, True):  ("  # [win]",            "      skip: True  # [not win]"),
                      (False, True,  False): ("  # [linux]",          "      skip: True  # [not linux]")}


def cache_file(src_cache, url, fn=None, sha=None, checksummer=hashlib.sha256):
    if fn:
        source = dict({'url': url, 'fn': fn, 'sha256': sha})
    else:
        source = dict({'url': url, 'sha256': sha})
    cached_path, _ = download_to_cache(src_cache, '', source)
    csum = checksummer()
    csum.update(open(cached_path, 'rb').read())
    csumstr = csum.hexdigest()
    return cached_path, csumstr


def yaml_quote_string(string, indent=2):
    """
    Quote a string for use in YAML.

    We can't just use yaml.dump because it adds ellipses to the end of the
    string, and it in general doesn't handle being placed inside an existing
    document very well.

    Note that this function is NOT general.
    """
    return yaml.dump(string, Dumper=SafeDumper).replace('\n...\n', '').replace('\n', '\n'+' '*indent)


def main():

    is_github_url = False

    this_dir = os.getcwd()

    # Unpack
    config = Config()
    cran_metadata = {}
    # Some packages are missing on some systems. Need to mark them so they get skipped.
    to_be_packaged = set()
    with TemporaryDirectory() as merged_td:
        for platform, details in sources.items():
            with TemporaryDirectory() as td:
                os.chdir(td)
                libdir = None
                # libarchive cannot handle the .exe, just skip it. Means we cannot figure out packages that are not available
                # for Windows.
                if platform == 'win_no':
                    details['cached_as'], sha256 = cache_file(config.src_cache, details['url'], details['fn'], details['sha'])
                    libarchive.extract_file(details['cached_as'])
                    libdir = os.path.join(td, details['library'])
                    library = os.listdir(libdir)
                    print(library)
                    details['to_be_packaged'] = set(library) - set(R_BASE_PACKAGE_NAMES)
                elif platform == 'linux':
                    details['cached_as'], sha256 = cache_file(config.src_cache, details['url'], details['fn'], details['sha'])
                    libarchive.extract_file(details['cached_as'])
                    import glob
                    for filename in glob.iglob('**/*.rpm', recursive=True):
                        print(filename)
                        libarchive.extract_file(filename)
                    libdir = os.path.join(td, details['library'])
                    library = os.listdir(libdir)
                    print(library)
                    details['to_be_packaged'] = set(library) - set(R_BASE_PACKAGE_NAMES)
                elif platform == 'mac':
                    details['cached_as'], sha256 = cache_file(config.src_cache, details['url'], details['fn'], details['sha'])
                    os.system("xar -xf {}".format(details['cached_as']))
                    payloads = glob.glob('./**/Payload', recursive=True)
                    print(payloads)
                    for payload in payloads:
                        libarchive.extract_file(payload)
                    libdir = os.path.join(td, details['library'])
                    library = os.listdir(libdir)
                    print(library)
                    details['to_be_packaged'] = set(library) - set(R_BASE_PACKAGE_NAMES)
                if libdir:
                    distutils.dir_util.copy_tree(libdir, merged_td)
        os.chdir(merged_td)
        libdir = merged_td
        # Fudge until we can unpack the Windows installer .exe on Linux
        sources['win']['to_be_packaged'] = sources['linux']['to_be_packaged']

        # Get the superset of all packages (note we will no longer have the DESCRIPTION?!)
        for platform, details in sources.items():
            if 'to_be_packaged' in details:
                to_be_packaged.update(details['to_be_packaged'])

        package_dicts = {}
        for package in sorted(list(to_be_packaged)):
            p = os.path.join(libdir, package, "DESCRIPTION")
            with open(p) as cran_description:
                description_text = cran_description.read()
                d = dict_from_cran_lines(remove_package_line_continuations(
                    description_text.splitlines()))
                d['orig_description'] = description_text
                package = d['Package'].lower()
                cran_metadata[package] = d

            # Make sure package always uses the CRAN capitalization
            package = cran_metadata[package.lower()]['Package']
            package_dicts[package.lower()] = {}
            package_dicts[package.lower()]['osx'] = True if package in sources['mac']['to_be_packaged'] else False
            package_dicts[package.lower()]['win'] = True if package in sources['win']['to_be_packaged'] else False
            package_dicts[package.lower()]['linux'] = True if package in sources['linux']['to_be_packaged'] else False
        for package in sorted(list(to_be_packaged)):
            cran_package = cran_metadata[package.lower()]

            package_dicts[package.lower()].update(
                {
                    'cran_packagename': package,
                    'packagename': 'r-' + package.lower(),
                    'patches': '',
                    'build_number': 0,
                    'build_depends': '',
                    'run_depends': '',
                    # CRAN doesn't seem to have this metadata :(
                    'home_comment': '#',
                    'homeurl': '',
                    'summary_comment': '#',
                    'summary': '',
                })
            d = package_dicts[package.lower()]
            d['url_key'] = 'url:'
            d['fn_key'] = 'fn:'
            d['git_url_key'] = ''
            d['git_tag_key'] = ''
            d['git_url'] = ''
            d['git_tag'] = ''
            d['hash_entry'] = ''
            d['build'], d['skip'] = build_and_skip_olw[(package_dicts[package.lower()]['osx'],
                                                        package_dicts[package.lower()]['linux'],
                                                        package_dicts[package.lower()]['win'])]
            d['cran_version'] = cran_package['Version']
            # Conda versions cannot have -. Conda (verlib) will treat _ as a .
            d['conda_version'] = d['cran_version'].replace('-', '_')

            patches = []
            script_env = []
            extra_recipe_maintainers = []
            build_number = 0
            if not len(patches):
                patches.append("# patches:\n")
                patches.append("   # List any patch files here\n")
                patches.append("   # - fix.patch")
            if len(extra_recipe_maintainers):
                extra_recipe_maintainers[1:].sort()
                extra_recipe_maintainers.insert(0, "extra:\n  ")
            d['build_number'] = build_number

            cached_path = None
            d['cran_metadata'] = '\n'.join(['# %s' % l for l in
                                            cran_package['orig_lines'] if l])

            # XXX: We should maybe normalize these
            d['license'] = cran_package.get("License", "None")
            d['license_family'] = guess_license_family(d['license'], allowed_license_families)

            if 'License_is_FOSS' in cran_package:
                d['license'] += ' (FOSS)'
            if cran_package.get('License_restricts_use') == 'yes':
                d['license'] += ' (Restricts use)'

            if "URL" in cran_package:
                d['home_comment'] = ''
                d['homeurl'] = ' ' + yaml_quote_string(cran_package['URL'])
            else:
                # use CRAN page as homepage if nothing has been specified
                d['home_comment'] = ''
                d['homeurl'] = ' https://mran.microsoft.com/package/{}'.format(package)

            if 'Description' in cran_package:
                d['summary_comment'] = ''
                d['summary'] = ' ' + yaml_quote_string(cran_package['Description'], indent=6)

            if "Suggests" in cran_package:
                d['suggests'] = "    # Suggests: %s" % cran_package['Suggests']
            else:
                d['suggests'] = ''

            if package.lower() == 'revoutilsmath':
                d['always_include_files'] = "      always_include_files:\n" \
                                            "        - lib/R/lib/libRblas.so  # [linux]"
            else:
                d['always_include_files'] = ''

            # Every package depends on at least R.
            # I'm not sure what the difference between depends and imports is.
            depends = [s.strip() for s in cran_package.get('Depends',
                                                           '').split(',') if s.strip()]
            imports = [s.strip() for s in cran_package.get('Imports',
                                                           '').split(',') if s.strip()]
            links = [s.strip() for s in cran_package.get("LinkingTo",
                                                         '').split(',') if s.strip()]

            dep_dict = {}

            seen = set()
            for s in list(chain(imports, depends, links)):
                match = VERSION_DEPENDENCY_REGEX.match(s)
                if not match:
                    sys.exit("Could not parse version from dependency of %s: %s" %
                             (package, s))
                name = match.group('name')
                if name in seen:
                    continue
                seen.add(name)
                archs = match.group('archs')
                relop = match.group('relop') or ''
                ver = match.group('version') or ''
                ver = ver.replace('-', '_')
                # If there is a relop there should be a version
                assert not relop or ver

                if archs:
                    sys.exit("Don't know how to handle archs from dependency of "
                             "package %s: %s" % (package, s))

                dep_dict[name] = '{relop}{version}'.format(relop=relop, version=ver)

            if 'R' not in dep_dict:
                dep_dict['R'] = ''

            need_git = is_github_url
            if cran_package.get("NeedsCompilation", 'no') == 'yes' and False:
                with tarfile.open(cached_path) as tf:
                    need_f = any([f.name.lower().endswith(('.f', '.f90', '.f77')) for f in tf])
                    # Fortran builds use CC to perform the link (they do not call the linker directly).
                    need_c = True if need_f else \
                        any([f.name.lower().endswith('.c') for f in tf])
                    need_cxx = any([f.name.lower().endswith(('.cxx', '.cpp', '.cc', '.c++'))
                                    for f in tf])
                    need_autotools = any([f.name.lower().endswith('/configure') for f in tf])
                    need_make = True if any((need_autotools, need_f, need_cxx, need_c)) else \
                        any([f.name.lower().endswith(('/makefile', '/makevars'))
                             for f in tf])
            else:
                need_c = need_cxx = need_f = need_autotools = need_make = False
            for dep_type in ['build', 'run']:

                deps = []
                # Put non-R dependencies first.
                if dep_type == 'build':
                    if need_c:
                        deps.append("{indent}{{{{ compiler('c') }}}}        # [not win]".format(
                            indent=INDENT))
                    if need_cxx:
                        deps.append("{indent}{{{{ compiler('cxx') }}}}      # [not win]".format(
                            indent=INDENT))
                    if need_f:
                        deps.append("{indent}{{{{ compiler('fortran') }}}}  # [not win]".format(
                            indent=INDENT))
                    if need_c or need_cxx or need_f:
                        deps.append("{indent}{{{{native}}}}toolchain        # [win]".format(
                            indent=INDENT))
                    if need_autotools or need_make or need_git:
                        deps.append("{indent}{{{{posix}}}}filesystem        # [win]".format(
                            indent=INDENT))
                    if need_git:
                        deps.append("{indent}{{{{posix}}}}git".format(indent=INDENT))
                    if need_autotools:
                        deps.append("{indent}{{{{posix}}}}sed               # [win]".format(
                            indent=INDENT))
                        deps.append("{indent}{{{{posix}}}}grep              # [win]".format(
                            indent=INDENT))
                        deps.append("{indent}{{{{posix}}}}autoconf".format(indent=INDENT))
                        deps.append("{indent}{{{{posix}}}}automake".format(indent=INDENT))
                        deps.append("{indent}{{{{posix}}}}pkg-config".format(indent=INDENT))
                    if need_make:
                        deps.append("{indent}{{{{posix}}}}make".format(indent=INDENT))
                elif dep_type == 'run':
                    if need_c or need_cxx or need_f:
                        deps.append("{indent}{{{{native}}}}gcc-libs         # [win]".format(
                            indent=INDENT))

                for name in sorted(dep_dict):
                    if name in R_BASE_PACKAGE_NAMES:
                        continue
                    if name == 'R':
                        # Put R first
                        # Regarless of build or run, and whether this is a recommended package or not,
                        # it can only depend on 'r-base' since anything else can and will cause cycles
                        # in the dependency graph. The cran metadata lists all dependencies anyway, even
                        # those packages that are in the recommended group.
                        r_name = 'r-base ' + VERSION
                        # We don't include any R version restrictions because we
                        # always build R packages against an exact R version
                        deps.insert(0, '{indent}{r_name}'.format(indent=INDENT, r_name=r_name))
                        # Bit of a hack since I added overlinking checking.
                        r_name = 'mro-base ' + VERSION
                        deps.insert(1, '{indent}{r_name}'.format(indent=INDENT, r_name=r_name))

                    else:
                        conda_name = 'r-' + name.lower()

                        if dep_dict[name]:
                            deps.append('{indent}{name} {version}'.format(name=conda_name,
                                                                          version=dep_dict[name], indent=INDENT))
                        else:
                            deps.append('{indent}{name}'.format(name=conda_name,
                                                                indent=INDENT))

                d['dep_dict'] = dep_dict  # We need this for (1)

                # Make pin_subpackage from the deps. Done separately so the above is the same as conda-build's
                # CRAN skeleton (so it is easy to refactor CRAN skeleton so it can be reused here later).
                for i, dep in enumerate(deps):
                    groups = re.match('(\n.* - )([\w-]+) ?([>=\w0-9._]+)?', dep, re.MULTILINE)
                    indent = groups.group(1)
                    name = groups.group(2)
                    pinning = groups.group(3)
                    if pinning:
                        if '>=' in pinning:
                            deps[i] = "{}{{{{ pin_subpackage('{}', min_pin='{}', max_pin=None) }}}}".format(indent, name, pinning.replace('>=', ''))
                        else:
                            if name == 'r-base':
                                # We end up with filenames with 'r34*' in them unless we specify the version here.
                                # TODO :: Ask @msarahan about this.
                                deps[i] = "{}{} {{{{ version }}}}".format(indent, name)
                            else:
                                deps[i] = "{}{{{{ pin_subpackage('{}', min_pin='{}', max_pin='{}') }}}}".format(indent, name, pinning, pinning)
                    else:
                        deps[i] = "{}{{{{ pin_subpackage('{}', min_pin='x.x.x.x.x.x', max_pin='x.x.x.x.x.x') }}}}".format(indent, name)

                # Add missing conda package dependencies.
                if dep_type == 'run':
                    if d['packagename'] in extra_deps:
                        for extra_dep in extra_deps[d['packagename']]:
                            print("extra_dep is {}".format(extra_dep))
                            deps.append(extra_dep)
                        print(deps)

                d['%s_depends' % dep_type] = ''.join(deps)

        template={'version': VERSION,
                  'win_url': sources['win']['url'],
                  'win_fn': sources['win']['fn'],
                  'win_sha': sources['win']['sha'],
                  'linux_url': sources['linux']['url'],
                  'linux_fn': sources['linux']['fn'],
                  'linux_sha': sources['linux']['sha'],
                  'mac_url': sources['mac']['url'],
                  'mac_fn': sources['mac']['fn'],
                  'mac_sha': sources['mac']['sha']}

        with open(os.path.join(this_dir, 'meta.yaml'), 'w') as meta_yaml:
            meta_yaml.write(HEADER.format(**template))
            meta_yaml.write(BASE_PACKAGE)

            for package in package_dicts:
                d = package_dicts[package]

                # Normalize the metadata values
                d = {k: unicodedata.normalize("NFKD", text_type(v)).encode('ascii', 'ignore')
                    .decode() for k, v in iteritems(d)}

                meta_yaml.write(PACKAGE.format(**d))

            meta_yaml.write(MRO_BASICS_METAPACKAGE)
            meta_subs = []
            for package in package_dicts:
                meta_subs.append('        - {}{}'.format(package_dicts[package]['packagename'], package_dicts[package]['build']))
            meta_yaml.write('\n'.join(sorted(meta_subs)))

        with open(os.path.join(this_dir, 'build.sh'), 'w') as build_sh:
            build_sh.write(BUILD_SH.format(**template))

        with open(os.path.join(this_dir, 'install-mro-base.sh'), 'w') as install_mro_base:
            install_mro_base.write(INSTALL_MRO_BASE_HEADER.format(**template))
            for excluded in sorted(to_be_packaged, key=lambda s: s.lower()):
                install_mro_base.write('EXCLUDED_PACKAGES+=('+excluded+')\n')
            install_mro_base.write(INSTALL_MRO_BASE_FOOTER.format(**template))

        with open(os.path.join(this_dir, 'install-r-package.sh'), 'w') as install_r_package:
            install_r_package.write(INSTALL_R_PACKAGE.format(**template))

if __name__ == '__main__':
    main()
