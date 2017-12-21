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

from itertools import chain

from conda_build.conda_interface import text_type, iteritems
from conda_build.config import Config
from conda_build.skeletons.cran import (dict_from_cran_lines, remove_package_line_continuations)
from conda_build.skeletons.cran import R_BASE_PACKAGE_NAMES as R_BASE_PACKAGE_NAMES_ORIG
from conda_build.source import download_to_cache
from conda_build.license_family import allowed_license_families, guess_license_family

from tempfile import TemporaryDirectory

VERSION = '3.4.1'
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

sources = {'win': {      'url': 'https://mran.blob.core.windows.net/install/mro/3.4.1/microsoft-r-open-'+VERSION+'.exe',
                          'fn': 'microsoft-r-open-'+VERSION+'.exe',
                         'sha': '04f7be3aaf393937b2edb536f1a3c7f279145b3aeb6e5eefdf9bee1ac137afc6',
                     'library': 'library'},
# This does not contain MKL:
#           'win': {      'url': 'https://go.microsoft.com/fwlink/?linkid=852724',
#                          'fn': 'SRO_'+VERSION+'.0_1033.cab',
#                         'sha': 'cb2632c339ae5211cb3475bf33b8ad9c3159f410c11d34ffca85d0527f872985',
#                     'library': 'library'},
           'linux': {    'url': 'https://mran.blob.core.windows.net/install/mro/'+VERSION+'/microsoft-r-open-'+VERSION+'.tar.gz',
                          'fn': 'microsoft-r-open-'+VERSION+'.tar.gz',
                         'sha': '83c2f36f255483e49cefa91a143c020ad9dfdfd70a101432f1eae066825261cb',
                     'library': 'opt/microsoft/ropen/3.4.1/lib64/R/library'},
           'mac': {      'url': 'https://mran.blob.core.windows.net/install/mro/'+VERSION+'/microsoft-r-open-'+VERSION+'.pkg',
                          'fn': 'microsoft-r-open-'+VERSION+'.pkg',
                         'sha': '643c5e953a02163ae73273da27f9c1752180f55bf836b127b6e1829fd1756fc8',
                     'library': 'R/library'}}

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
'''

PACKAGE='''
  - name: {packagename}
    version: {conda_version}
    script: install-r-package.sh
    # This is required to make R link correctly on Linux.
    build:
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
        mv Microsoft/MRO-3.4.1.0/Setup/MKL_2017.0.36.5_1033.cab "$SRC_DIR"/unpack
        mv Microsoft/MRO-3.4.1.0/Setup/MROPKGS_9.2.0.0_1033.cab "$SRC_DIR"/unpack
        # This contains VCRT_14.0.23026.0_1033.exe and RSetup.exe
        rm -rf Microsoft/MRO-3.4.1.0/Setup
        mkdir -p "$SRC_DIR"/unpack/lib
        mv Microsoft/MRO-3.4.1.0 "$SRC_DIR"/unpack/lib/R
        # msiexec -a $(cygpath -w $PWD/Microsoft/MRO-3.4.1.0/Setup/MKL_2017.0.36.5_1033.cab) -qb TARGETDIR=$(cygpath -w "$SRC_DUR"/unpack)
        # msiexec -a $(cygpath -w $PWD/Microsoft/MRO-3.4.1.0/Setup/MROPKGS_9.2.0.0_1033.cab) -qb TARGETDIR=$(cygpath -w "$SRC_DUR"/unpack)
        # TODO :: The MKL archive should probably be unpacked when during install-r-package.sh for RevoUtilsMath instead.
        ARCHIVES+=(MKL_2017.0.36.5_1033.cab,lib/R)
        ARCHIVES+=(MROPKGS_9.2.0.0_1033.cab,lib/R)
        echo ARCHIVES are ${{ARCHIVES[@]}}
      popd
    else
      ARCHIVES+=($ARCHIVE,.)
    fi
    for ARCHIVE_DEST in "${{ARCHIVES[@]}}"; do
      ARCHIVE=${{ARCHIVE_DEST//,*/}}
      DEST=${{ARCHIVE_DEST#*,}}
      mv $ARCHIVE $DEST/
      pushd $DEST
        python -c "import libarchive, os; libarchive.extract_file('$ARCHIVE')" || exit 1
        rm $ARCHIVE
      popd
    done
  fi
  # Even on Darwin, libarchive will fail to unpack a .pkg file.
  # if [[ $? != 0 ]]; then  # for some reason the script exits if libarchive fails to unpack?
  if [[ $target_platform == osx-64 ]]; then
    xar -xf ../$ARCHIVE
    for PAYLOAD in $(find . -name Payload); do
      cat "$PAYLOAD" | gunzip -dc | cpio -i
    done
    rm -rf R_Open_App.pkg R_Open_Framework.pkg Distribution
  elif [[ $target_platform == linux-64 ]]; then
    # TODO :: May need to put the MKL libs into a separate package (actually they're in r-revoutilsmath)
    for RPM in $(find rpm -name "*.rpm"); do
      echo $RPM
      python -c "import libarchive, os; libarchive.extract_file('$RPM')" || true
      find .
    done
  fi
  find . | sort > $RECIPE_DIR/filelist-mro-$target_platform.txt

  # 2. Save filelist back to the recipe.
  find . | LC_COLLATE=C sort --ignore-case > "$RECIPE_DIR"/filelist-mro-$target_platform.txt

  # 3. Rearrange layout so it is compatible with conda, or at least does not stomp all over
  #    conda packages (MKL for example).
  if [[ $target_platform == linux-64 ]]; then
    mv opt/microsoft/ropen/3.4.1/lib64 lib
    mv opt/microsoft/ropen/3.4.1/stage stage
  elif [[ $target_platform == osx-64 ]]; then
    echo "No layout changes necessary for $target_platform"
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
    echo "No fixes necessary for $target_platform"
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
  find . | LC_COLLATE=C sort --ignore-case > "$RECIPE_DIR"/filelist-mro-$target_platform.end-of-build-sh.txt
popd
'''

INSTALL_MRO_BASE_HEADER='''#!/bin/bash

contains () {{
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}}

make_mro_base () {{
  if [[ $target_platform == osx-64 ]]; then
    FRAMEWORK=/Library/Frameworks/R.framework
    LIBRARY=$FRAMEWORK/Versions/{version}-MRO/Resources/library
    PREFIX_LIB="$PREFIX"/lib/R
  elif [[ $target_platform == win-64 ]]; then
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
    FRAMEWORK=
    LIBRARY=$FRAMEWORK/lib/R/library
    PREFIX_LIB="$PREFIX"/lib/R/library
  else
    FRAMEWORK=
    LIBRARY=$FRAMEWORK/lib/R/library
    PREFIX_LIB="$PREFIX"/lib/R/library
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
        ln -s ../lib/R/bin/$EXE $EXE || exit 1
      done
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

  pushd unpack$LIBRARY/.. || exit 1
    mv library ../
    [[ -d lib/mro_mkl ]] && mv lib/mro_mkl ../
    # We have no m2-rsync unfortunately.
    # rsync -avv . "$PREFIX" || exit 1
    cp -rf * "$PREFIX"/lib/R/
    mv ../library .
    [[ -d ../mro_mkl ]] && mv ../mro_mkl lib/
    pushd $PREFIX
      find . > $RECIPE_DIR/filelist-mro-base-in-prefix-$target_platform.txt
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

if [[ $target_platform == osx-64 ]]; then
  FRAMEWORK=/Library/Frameworks/R.framework
  LIBRARY=$FRAMEWORK/Versions/{version}-MRO/Resources/library
elif [[ $target_platform == win-64 ]]; then
  FRAMEWORK=
  LIBRARY=$FRAMEWORK/lib/R/library
  PREFIX_LIB="$PREFIX"/lib/R/library
else
FRAMEWORK=
  LIBRARY=$FRAMEWORK/lib/R/library
  PREFIX_LIB="$PREFIX"/lib/R/library
fi

mkdir -p "$PREFIX"$LIBRARY

if [[ "$LIBRARY_NAME" == "revoutilsmath" ]] && [[ $target_platform == linux-64 ]]; then
  mkdir -p "$PREFIX"/lib/R/lib/mro_mkl/
  mv unpack/lib/R/lib/mro_mkl/* "$PREFIX"/lib/R/lib/mro_mkl/
  mv "$PREFIX"/lib/R/lib/mro_mkl/libRblas.so "$PREFIX"/lib/R/lib/
fi

pushd unpack$LIBRARY || exit 1
  for LIBRARY_CASED in $(find . -iname "$LIBRARY_NAME" -maxdepth 1 -mindepth 1); do
    mv $LIBRARY_CASED "$PREFIX_LIB"/
  done
popd

find . | wc -l
'''


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
    with TemporaryDirectory() as td:
        for platform, details in sources.items():
            # if platform != 'mac' and platform != 'win': # Cannot extract macOS .pkg files on Linux.
            if platform == 'win_no':
                details['cached_as'], sha256 = cache_file(config.src_cache, details['url'], details['fn'], details['sha'])
                os.chdir(td)
                libarchive.extract_file(details['cached_as'])
                libdir = os.path.join(td, details['library'])
                library = os.listdir(libdir)
                # library.append('foreach')
                to_be_packaged = set(library) - set(R_BASE_PACKAGE_NAMES)
            elif platform == 'linux':
                details['cached_as'], sha256 = cache_file(config.src_cache, details['url'], details['fn'], details['sha'])
                os.chdir(td)
                libarchive.extract_file(details['cached_as'])
                import glob
                for filename in glob.iglob('**/*.rpm', recursive=True):
                    print(filename)
                    libarchive.extract_file(filename)
                libdir = os.path.join(td, details['library'])
                library = os.listdir(libdir)
                # library.append('foreach')
                to_be_packaged = set(library) - set(R_BASE_PACKAGE_NAMES)
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
                        r_name = 'mro-base ' + VERSION
                        # We don't include any R version restrictions because we
                        # always build R packages against an exact R version
                        deps.insert(0, '{indent}{r_name}'.format(indent=INDENT, r_name=r_name))
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
                            deps[i] = "{}{{{{ pin_subpackage('{}', min_pin='{}', max_pin='{}') }}}}".format(indent, name, pinning, pinning)
                    else:
                        deps[i] = "{}{{{{ pin_subpackage('{}', min_pin='x.x.x.x.x.x', max_pin='x.x.x.x.x.x') }}}}".format(indent, name)

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
                meta_subs.append('        - {}'.format(package_dicts[package]['packagename']))
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
