#!/bin/bash

if [[ $target_platform == win-64 ]]; then
  ARCHIVE=microsoft-r-open-3.4.1.exe
elif [[ $target_platform == linux-64 ]]; then
  ARCHIVE=microsoft-r-open-3.4.1.tar.gz
elif [[ $target_platform == osx-64 ]]; then
  ARCHIVE=microsoft-r-open-3.4.1.pkg
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
      popd
    elif [[ $target_platform == osx-64 ]]; then
      # https://github.com/libarchive/libarchive/issues/456
      xar -xf $ARCHIVE
      for PAYLOAD in $(find . -name Payload); do
        ARCHIVES+=($PAYLOAD,.)
      done
    else
      ARCHIVES+=($ARCHIVE,.)
    fi
    echo ARCHIVES are ${ARCHIVES[@]}
    for ARCHIVE_DEST in "${ARCHIVES[@]}"; do
      ARCHIVE=${ARCHIVE_DEST//,*/}
      DEST=${ARCHIVE_DEST#*,}
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
    mv opt/microsoft/ropen/3.4.1/lib64 lib
    mv opt/microsoft/ropen/3.4.1/stage stage
  elif [[ $target_platform == osx-64 ]]; then
    FRAMEWORK=/Library/Frameworks/R.framework
    RESOURCES=$FRAMEWORK/Versions/$PKG_VERSION-MRO/Resources
    mkdir -p lib/R
    mv .$RESOURCES/library lib/R/
    mv .$RESOURCES/lib lib/R/
    mv .$RESOURCES/bin lib/R/
    mv .$RESOURCES/modules lib/R/
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
    declare -a DYLIBS
    for DYLIB in $(find . -name "*.dylib" -or -name "*.so"); do
      DYLIBS+=($DYLIB)
      install_name_tool -id $(basename $DYLIB) $DYLIB
    done
    echo "DYLIBS are:"
    for DYLIB in ${DYLIBS[@]}; do
      echo $DYLIB
    done
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
    PATH="$PREFIX"/Library/mingw-w64/bin:$PATH \
      $WINE "$PREFIX"/Library/mingw-w64/bin/gcc.exe -DGUI=0 -O -s -o "$SRC_DIR"/launcher.exe "$RECIPE_DIR"/launcher.c || exit 1
  popd
fi

# 7. Save end of build.sh filelist back to the recipe.
pushd unpack
  find . | LC_COLLATE=C sort --ignore-case > "$RECIPE_DIR"/filelist-mro-$PKG_VERSION-$target_platform.end-of-build-sh.txt
popd
