#!/bin/bash

if [[ $target_platform == win-64 ]]; then
  ARCHIVE=SRO_3.4.1.0_1033.cab
elif [[ $target_platform == linux-64 ]]; then
  ARCHIVE=microsoft-r-open-3.4.1.tar.gz
elif [[ $target_platform == osx-64 ]]; then
  ARCHIVE=microsoft-r-open-3.4.1.pkg
fi

# If conda-build used libarchive to unpack things this would not need to exist
mkdir -p unpack
pushd unpack
  if [[ -f ../$ARCHIVE ]]; then
    python -c "import libarchive, os; libarchive.extract_file('../$ARCHIVE')" || true
  fi
  # Even on Darwin, libarchive will fail to unpack a .pkg file.
  # if [[ $? != 0 ]]; then  # for some reason the script exits if libarchive fails to unpack?
  if [[ $target_platform == osx-64 ]]; then
    xar -xf ../$ARCHIVE
    for PAYLOAD in $(find . -name Payload); do
      cat "$PAYLOAD" | gunzip -dc | cpio -i
    done
    rm -rf R_Open_App.pkg R_Open_Framework.pkg Distribution
  fi
  find . | sort > $RECIPE_DIR/filelist-mro-$target_platform.txt
popd
if [[ $target_platform == win-64 ]]; then
  env
  # Compile the launcher
  # XXX: Should we build Rgui with -DGUI=1 -mwindows?  The only difference is
  # that it doesn't block the terminal, but we also can't get the return
  # value for the conda build tests.
  # NOTE: This needs to be run on Windows or via Wine.
  if [[ ! $(uname) =~ M* ]]; then
    WINE=wine
    if ! which $WINE; then
      echo "To build mro-base you need Wine"
      exit 1
    fi
  fi
  $WINE "$PREFIX"/Library/mingw-w64/bin/gcc.exe -DGUI=0 -O -s -o launcher.exe "$RECIPE_DIR"/launcher.c || exit 1
fi
