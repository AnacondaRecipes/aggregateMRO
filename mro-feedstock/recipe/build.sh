#!/bin/bash

. "${RECIPE_DIR}"/find_relative_path.sh

RC_PKG_VERSION=3.4.1

if [[ $target_platform == win-64 ]]; then
  ARCHIVE=microsoft-r-open-3.4.3.exe
elif [[ $target_platform == linux-64 ]]; then
  ARCHIVE=microsoft-r-open-3.4.3.tar.gz
elif [[ $target_platform == osx-64 ]]; then
  ARCHIVE=microsoft-r-open-3.4.3.pkg
fi

declare -a MKL_USING_LIBS
MKL_USING_LIBS+=(lib/R/library/RevoUtilsMath/libs/RevoUtilsMath.so)
MKL_USING_LIBS+=(lib/R/library/RevoScaleR/rxLibs/x64/libExaServer.so.2)
MKL_USING_LIBS+=(lib/R/library/RevoScaleR/rxLibs/x64/libExaCore.so.2)
MKL_USING_LIBS+=(lib/R/library/RevoScaleR/rxLibs/x64/libExaMpiComm.so.2)
MKL_USING_LIBS+=(lib/R/library/RevoScaleR/rxLibs/x64/libBxServerLink.so.2)
MKL_USING_LIBS+=(lib/R/library/RevoScaleR/rxLibs/x64/libExacorePredict.so.2)
MKL_USING_LIBS+=(lib/R/library/RevoScaleR/rxLibs/x64/BxlServer)
# Does not use MKL, but we need its RPATHs modified to include lib/R/lib
MKL_USING_LIBS+=(lib/R/library/RevoScaleR/rxLibs/x64/libRxLink.so.2)

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
        mv Microsoft/MRO-$PKG_VERSION.0/Setup/MROPKGS_9.3.0.0_1033.cab "$SRC_DIR"/unpack
        # This contains VCRT_14.0.23026.0_1033.exe and RSetup.exe
        rm -rf Microsoft/MRO-$PKG_VERSION.0/Setup
        mkdir -p "$SRC_DIR"/unpack/lib
        mv Microsoft/MRO-$PKG_VERSION.0 "$SRC_DIR"/unpack/lib/R
        # msiexec -a $(cygpath -w $PWD/Microsoft/MRO-$PKG_VERSION.0/Setup/MKL_2017.0.36.5_1033.cab) -qb TARGETDIR=$(cygpath -w "$SRC_DUR"/unpack)
        # msiexec -a $(cygpath -w $PWD/Microsoft/MRO-$PKG_VERSION.0/Setup/MROPKGS_9.3.0.0_1033.cab) -qb TARGETDIR=$(cygpath -w "$SRC_DUR"/unpack)
        # TODO :: The MKL archive should probably be unpacked when during install-r-package.sh for RevoUtilsMath instead.
        ARCHIVES+=(MKL_2017.0.36.5_1033.cab,lib/R)
        ARCHIVES+=(MROPKGS_9.3.0.0_1033.cab,lib/R)
      popd
    elif [[ $target_platform == osx-64 ]]; then
      # https://github.com/libarchive/libarchive/issues/456
      xar -xf $ARCHIVE
      rm $ARCHIVE
      for PAYLOAD in $(find . -name Payload); do
        ARCHIVES+=($PAYLOAD,.)
      done
    else
      # THIS IS NEVER HIT
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
    done
    python -c "import libarchive, os; libarchive.extract_file('$PWD/../unpack-r-client/microsoft-r-client-packages-$RC_PKG_VERSION.rpm')" || true
  elif [[ $target_platform == win-64 ]]; then
    pushd $(mktemp -d)
      "$SRC_DIR"/wix/dark.exe $SRC_DIR/unpack-r-client/RClientSetup.exe -x $PWD
      find .
      cp ./AttachedContainer/AsOleDB_13.0.1601.5_1033.msi $SRC_DIR/unpack-r-client
      cp ./AttachedContainer/MPI_7.1.12437.25_1033.exe $SRC_DIR/unpack-r-client
      cp ./AttachedContainer/RClient.msi $SRC_DIR/unpack-r-client
    popd
    msiexec -a $(cygpath -w $PWD/../unpack-r-client/AsOleDB_13.0.1601.5_1033.msi) -qb TARGETDIR=$(cygpath -w "$PWD"/AsOleDB)
    msiexec -a $(cygpath -w $PWD/../unpack-r-client/RClient.msi) -qb TARGETDIR=$(cygpath -w "$PWD"/RClient)
    # "$SRC_DIR"/wix/dark.exe ../unpack-r-client/AsOleDB_13.0.1601.5_1033.msi -x $PWD/AsOleDB
    # "$SRC_DIR"/wix/dark.exe ../unpack-r-client/RClient.msi -x $PWD
    # Yuck, not sure what the problem is here.
    $(dirname $(dirname $(dirname $(which 7z))))/usr/lib/p7zip/7z x -o$PWD/MPI ../unpack-r-client/MPI_7.1.12437.25_1033.exe || exit 1
    # Finally, probably all we care about (or can care about):
    python -c "import libarchive, os; libarchive.extract_file('../unpack/RClient/Microsoft/R Client/Setup/SRS_9.2.1.0_1033.cab')" || true
    # Since R Client is older than MRO we must not use packages from it where there they also exist in MRO.
    rm -rf library/{iterators,foreach,RevoUtilsMath}
    mv library/* lib/R/library/
  fi

  # 2. Save filelist back to the recipe.
  find . | LC_COLLATE=C sort --ignore-case > "$RECIPE_DIR"/filelist-mro-$PKG_VERSION-$target_platform.after-unpacking.txt

  # 3. Rearrange layout so it is compatible with conda, or at least does not stomp all over
  #    conda packages (MKL for example).
  if [[ $target_platform == linux-64 ]]; then
    mv opt/microsoft/ropen/$PKG_VERSION/lib64 lib
    mv opt/microsoft/ropen/$PKG_VERSION/stage stage
    patch -p1 < $RECIPE_DIR/0001-r-client-Relocate-bin-R-R.patch
    pushd opt/microsoft/rclient/$RC_PKG_VERSION/libraries/RServer
      echo r-client libraries are:
      ls -l *
      mv * $SRC_DIR/unpack/lib/R/library/
    popd
    mv opt/microsoft/rclient $SRC_DIR/unpack/
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
    echo "No layout changes necessary for $target_platform"
  fi

  # 4. Implement any necessary fixes.
  if [[ $target_platform == linux-64 ]]; then
    # Workaround: https://github.com/Microsoft/microsoft-r-open/issues/15
    #        and: https://github.com/Microsoft/microsoft-r-open/issues/44
    pushd $(mktemp -d)
      curl -SLO http://vault.centos.org/5.11/os/x86_64/CentOS/libpng-1.2.10-17.el5_8.x86_64.rpm
      "$RECIPE_DIR"/rpm2cpio libpng-1.2.10-17.el5_8.x86_64.rpm | cpio -idmv
      cp -p usr/lib64/libpng12.so.0* "$SRC_DIR"/unpack/lib/R/modules/
      cp -p usr/lib64/libpng12.so.0* "$SRC_DIR"/unpack/lib/R/library/grDevices/libs/
    popd
    patchelf --set-rpath '$ORIGIN' lib/R/lib/libR.so

    # Add a missing RPATH (MRO probably used LD_LIBRARY_PATH for this):
    pushd lib/R/modules
      for SHARED_LIB in $(find . -type f -iname "*.so"); do
        patchelf --set-rpath '$ORIGIN':'$ORIGIN'/../lib $SHARED_LIB
      done
    popd
    patchelf --set-rpath '$ORIGIN'/../../lib lib/R/bin/exec/R
    patchelf --set-rpath '$ORIGIN' lib/R/lib/libRblas.so
    patchelf --set-rpath '$ORIGIN' lib/R/lib/libRlapack.so
    pushd lib/R/library
      for SHARED_LIB in $(find . -type f -iname "*.so"); do
        patchelf --set-rpath '$ORIGIN':'$ORIGIN'/../../../lib $SHARED_LIB
      done
    popd

    # Prevent the MRO MKL libraries from stomping over the files in Anaconda Distribution's MKL package.
    mkdir -p lib/R/lib/mro_mkl/
    mv stage/Linux/bin/x64/* lib/R/lib/mro_mkl/
    for LIBRARY in ${MKL_USING_LIBS[@]}; do
      OLD_RPATH=$(patchelf --print-rpath $LIBRARY)
      rp=$(rel_path $(dirname $PWD/$LIBRARY) $PWD/lib/R/lib/mro_mkl)
      echo rp from $PWD/$LIBRARY to $PWD/lib/R/lib/mro_mkl is $rp
      rp2=$(rel_path $(dirname $PWD/$LIBRARY) $PWD/lib/R/lib)
      patchelf --set-rpath '$ORIGIN'/$rp:'$ORIGIN'/$rp2:$OLD_RPATH $LIBRARY
    done
    rm -rf opt rpm stage
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
    for DYLIB in ${DYLIBS[@]}; do
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
  elif [[ $target_platform == win-64 ]]; then
    rm -rf lib/R/library/RevoUtils || exit 1
    mv $SRC_DIR/RevoUtils lib/R/library/ || exit 1
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

# TODO :: Patch out LD_LIBRARY_PATH stuff.

# 7. Save end of build.sh filelist back to the recipe.
pushd unpack
  find . | LC_COLLATE=C sort --ignore-case > "$RECIPE_DIR"/filelist-mro-$PKG_VERSION-$target_platform.end-of-build-sh.txt
popd