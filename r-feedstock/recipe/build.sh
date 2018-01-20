#!/bin/bash

if [[ $target_platform == win-64 ]]; then
  ARCHIVE=microsoft-r-open-3.4.3.exe
elif [[ $target_platform == linux-64 ]]; then
  ARCHIVE=microsoft-r-open-3.4.3.tar.gz
elif [[ $target_platform == osx-64 ]]; then
  ARCHIVE=microsoft-r-open-3.4.3.pkg
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
    # And all og the MS-provided GCC compiler runtime DSOs
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
    declare -a DYLIBS
    for DYLIB in $(find . -name "*.dylib" -or -name "*.so"); do
      DYLIBS+=($DYLIB)
      install_name_tool -id $(basename $DYLIB) $DYLIB
    done
    echo "DYLIBS are:"
    for DYLIB in ${DYLIBS[@]}; do
      echo $DYLIB
    done
    sed -i='' "s|$FRAMEWORK/Resources|$PREFIX/lib/R|g" lib/R/bin/R
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
    for libdir in lib/R/lib lib/R/modules lib/R/library lib/R/bin/exec; do
      pushd $libdir || exit 1
      echo "Pushed to libdir $libdir"
        for SHARED_LIB in $(find . -type f -iname "*.dylib" -or -iname "*.so" -or -iname "R"); do
          echo "fixing SHARED_LIB $SHARED_LIB"
          install_name_tool -change /Library/Frameworks/R.framework/Versions/3.4.3-MRO/Resources/lib/libR.dylib "$PREFIX"/lib/R/lib/libR.dylib $SHARED_LIB || true
          install_name_tool -change /usr/local/clang4/lib/libomp.dylib "$PREFIX"/lib/libomp.dylib $SHARED_LIB || true
          install_name_tool -change /usr/local/gfortran/lib/libgfortran.3.dylib "$PREFIX"/lib/libgfortran.3.dylib $SHARED_LIB || true
          install_name_tool -change /usr/local/gfortran/lib/libquadmath.0.dylib "$PREFIX"/lib/libquadmath.0.dylib $SHARED_LIB || true
          install_name_tool -change /usr/lib/libgcc_s.1.dylib "$PREFIX"/lib/libgcc_s.1.dylib $SHARED_LIB || true
          install_name_tool -change /usr/lib/libiconv.2.dylib "$PREFIX"/lib/libiconv.2.dylib $SHARED_LIB || true
          install_name_tool -change /usr/lib/libncurses.5.4.dylib "$PREFIX"/lib/libncursesw.6.dylib $SHARED_LIB || true
          # Cannot find a good single replacement for icucore.
          # install_name_tool -change /usr/lib/libicucore.A.dylib "$PREFIX"/lib/libiconv.6.dylib $SHARED_LIB || true
          install_name_tool -change /usr/lib/libexpat.1.dylib "$PREFIX"/lib/libexpat.1.dylib $SHARED_LIB || true
          install_name_tool -change /usr/lib/libcurl.4.dylib "$PREFIX"/lib/libcurl.4.dylib $SHARED_LIB || true
        done
      popd
    done
    # One-off fixups. It seems some packages were not rebuilt against R 3.4.3 (doing them for every dylib would be pointlessly slow):
    install_name_tool -change /Library/Frameworks/R.framework/Versions/3.4.0-MRO/Resources/lib/libR.dylib "$PREFIX"/lib/R/lib/libR.dylib lib/R/library/curl/libs/curl.so || true
    install_name_tool -change /Library/Frameworks/R.framework/Versions/3.4.0-MRO/Resources/lib/libR.dylib "$PREFIX"/lib/R/lib/libR.dylib lib/R/library/jsonlite/libs/jsonlite.so || true
    install_name_tool -change /Library/Frameworks/R.framework/Versions/3.4.0-MRO/Resources/lib/libR.dylib "$PREFIX"/lib/R/lib/libR.dylib lib/R/library/png/libs/png.so || true
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
