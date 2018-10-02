#!/bin/bash

set -x

if [[ $target_platform == osx-64 ]]; then
  SED_REGEX=-E
else
  SED_REGEX=-r
fi

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
      for EXE in $(find . -type f -maxdepth 1 -mindepth 1); do
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

  # Make symlinks to the Anaconda Distribution compilers on Linux
  if [[ $target_platform == linux-64 ]]; then
    pushd $PREFIX/bin
      ln -s $HOST-ar ar
      ln -s $HOST-cc cc
      ln -s $HOST-c++ c++
      ln -s $HOST-gcc gcc
      ln -s $HOST-g++ g++
      ln -s $HOST-gfortran fc
      ln -s $HOST-gfortran f77
      ln -s $HOST-gfortran gfortran
      ln -s $HOST-ranlib ranlib
      ln -s $HOST-strip strip
    popd
  fi

  mkdir -p "$PREFIX_LIB"

  pushd unpack$LIBRARY || exit 1
    for LIBRARY_CASED in $(find . -maxdepth 1 -mindepth 1); do
      LIBRARY_CASED=${LIBRARY_CASED//.\//}
      if ! contains $LIBRARY_CASED "${EXCLUDED_PACKAGES[@]}"; then
        echo "Including $LIBRARY_CASED => $PREFIX_LIB"
        mv $LIBRARY_CASED "$PREFIX_LIB"/
      else
        echo "Skipping $LIBRARY_CASED"
      fi
    done
  popd

  [[ -d unpack/sysroot ]] && mv unpack/sysroot $PREFIX

  if [[ $target_platform == win-64 ]]; then
    MAKECONF=lib/R/etc/x64/Makeconf
  else
    MAKECONF=lib/R/etc/Makeconf
  fi

  pushd unpack$LIBRARY/.. || exit 1
    mv library ../
    [[ -d lib/mro_mkl ]] && mv lib/mro_mkl ../
    # We have no m2-rsync unfortunately.
    # rsync -avv . "$PREFIX" || exit 1
    cp -rf * "$PREFIX"/lib/R/
    mv ../library .
    [[ -d ../mro_mkl ]] && mv ../mro_mkl lib/
  popd

  # Rewrite Makeconf to prefer our various flags.
  if [[ -f $RECIPE_DIR/Makeconf.$target_platform ]]; then
    pushd $PREFIX
      cp $RECIPE_DIR/Makeconf.$target_platform $MAKECONF
      sed -i.mro.original "s|/opt/anaconda1anaconda2anaconda3|$PREFIX|g" $MAKECONF
    popd
  fi

  # Call R CMD javareconf upon activation.
  if [[ $target_platform != win-64 ]]; then
    pushd "$PREFIX"
      patch -p1 < "${RECIPE_DIR}"/0010-javareconf-Do-not-fail-on-compile-fail.patch
      patch -p1 < "${RECIPE_DIR}"/0011-Revert-part-of-9b818c6dc00143ff18775a4015a3f43b5196f.patch
      patch -p1 < "${RECIPE_DIR}"/0012-javareconf-macOS-Continue-to-allow-system-Java-lt-9-.patch
    popd
    cp "$RECIPE_DIR"/activate-${PKG_NAME}.sh ${PREFIX}/etc/conda/activate.d/activate-${PKG_NAME}.sh
  fi

  # Prevent C and C++ extensions from linking to libgfortran.
  pushd "$PREFIX"
    if [[ -f $MAKECONF ]]; then
      sed -i.bak ${SED_REGEX} 's|(^LDFLAGS = .*)-lgfortran|\1|g' $MAKECONF
    fi
    if [[ $target_platform == osx-64 ]]; then
      if [[ ! -f lib/R/share/make/shlib.mk ]]; then
        echo "ERROR :: Missing lib/R/share/make/shlib.mk"
        find lib/R/share
        exit 1
      fi
    fi
    # Add our prefix/include to CPPFLAGS, needed for things like r-rodbc which queries this via `R CMD config CPPFLAGS`
    sed -i.bak "s|^\(CPPFLAGS = .*\)$|\1 -I${PREFIX}/include|g" $MAKECONF
    # Add our LDFLAGS too, this is important for -Wl,-headerpad_max_install_names and -Wl,-dead_strip_dylibs
    sed -i.bak "s|^\(LDFLAGS = .*\)$|\1 ${LDFLAGS}|g" $MAKECONF
    [[ -f $MAKECONF.bak ]] && rm -f $MAKECONF.bak
  popd

  # This file is included in RevoUtils instead, otherwise R fails to load.
  rm "$PREFIX"/lib/R/etc/Rprofile.site

  pushd $PREFIX
    find . | LC_COLLATE=C sort --ignore-case > "$RECIPE_DIR"/../filelists/mro-base-$PKG_VERSION-$target_platform.in-prefix.txt
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
EXCLUDED_PACKAGES+=(RevoUtils)
EXCLUDED_PACKAGES+=(RevoUtilsMath)
EXCLUDED_PACKAGES+=(rpart)
EXCLUDED_PACKAGES+=(RUnit)
EXCLUDED_PACKAGES+=(spatial)
EXCLUDED_PACKAGES+=(survival)
# RClient parts:
EXCLUDED_PACKAGES+=(RServer)
EXCLUDED_PACKAGES+=(CompatibilityAPI)
EXCLUDED_PACKAGES+=(RevoPemaR)
EXCLUDED_PACKAGES+=(RevoScaleR)
EXCLUDED_PACKAGES+=(RevoTDUtils)
EXCLUDED_PACKAGES+=(RevoTreeView)
EXCLUDED_PACKAGES+=(doRSR)
EXCLUDED_PACKAGES+=(mrsdeploy)
EXCLUDED_PACKAGES+=(mrupdate)
# RClient MicrosoftML parts:
EXCLUDED_PACKAGES+=(MicrosoftML)
make_mro_base
