#!/bin/bash

set -x

exec 1<&-
# Close STDERR FD
exec 2<&-

# Open STDOUT as $LOG_FILE file for read and write.
exec 1<> /c/Users/builder/conda/install-mro-base.log

# Redirect STDERR to STDOUT
exec 2>&1

contains () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

make_mro_base () {
  if [[ $target_platform == osx-64 ]]; then
    FRAMEWORK=/Library/Frameworks/R.framework
    LIBRARY=$FRAMEWORK/Versions/3.4.1-MRO/Resources/library
    PREFIX_LIB="$PREFIX"/lib/R
  elif [[ $target_platform == win-64 ]]; then
    FRAMEWORK=
    LIBRARY=$FRAMEWORK/library
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
    LIBRARY=$FRAMEWORK/lib/R/library
    PREFIX_LIB="$PREFIX"/lib/R/library
  else
    FRAMEWORK=
    LIBRARY=$FRAMEWORK/lib/R/library
    # Probably needs to be as-per win-64?
    PREFIX_LIB="$PREFIX"/lib/R/library
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
    # We have no m2-rsync unfortunately.
    # rsync -avv . "$PREFIX" || exit 1
    cp -rf * "$PREFIX"/lib/R/
    mv ../library .
    pushd $PREFIX
      find . > $RECIPE_DIR/filelist-mro-base-in-prefix-$target_platform.txt
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
