#!/bin/bash

# activate the build environment
. activate "$BUILD_PREFIX"

contains () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

make_mro_base () {
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
        EXE=${EXE//.\//}
        EXES+=($EXE)
      done
    popd
    pushd $PREFIX/bin
      for EXE in ${EXES[@]}; do
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
      LIBRARY_CASED=${LIBRARY_CASED//.\//}
      if ! contains $LIBRARY_CASED "${EXCLUDED_PACKAGES[@]}"; then
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
      find . | LC_COLLATE=C sort --ignore-case > "$RECIPE_DIR"/filelist-mro-base-$PKG_VERSION-$target_platform.in-prefix.txt
    popd
  popd
}
declare -a EXCLUDED_PACKAGES
EXCLUDED_PACKAGES+=(boot)
EXCLUDED_PACKAGES+=(checkpoint)
EXCLUDED_PACKAGES+=(class)
EXCLUDED_PACKAGES+=(cluster)
EXCLUDED_PACKAGES+=(codetools)
EXCLUDED_PACKAGES+=(curl)
EXCLUDED_PACKAGES+=(deployrRserve)
EXCLUDED_PACKAGES+=(doParallel)
EXCLUDED_PACKAGES+=(foreach)
EXCLUDED_PACKAGES+=(foreign)
EXCLUDED_PACKAGES+=(iterators)
EXCLUDED_PACKAGES+=(jsonlite)
EXCLUDED_PACKAGES+=(KernSmooth)
EXCLUDED_PACKAGES+=(lattice)
EXCLUDED_PACKAGES+=(MASS)
EXCLUDED_PACKAGES+=(Matrix)
EXCLUDED_PACKAGES+=(mgcv)
EXCLUDED_PACKAGES+=(MicrosoftR)
EXCLUDED_PACKAGES+=(nlme)
EXCLUDED_PACKAGES+=(nnet)
EXCLUDED_PACKAGES+=(png)
EXCLUDED_PACKAGES+=(R6)
EXCLUDED_PACKAGES+=(RevoIOQ)
EXCLUDED_PACKAGES+=(RevoMods)
EXCLUDED_PACKAGES+=(RevoUtilsMath)
EXCLUDED_PACKAGES+=(rpart)
EXCLUDED_PACKAGES+=(RUnit)
EXCLUDED_PACKAGES+=(spatial)
EXCLUDED_PACKAGES+=(survival)

make_mro_base
