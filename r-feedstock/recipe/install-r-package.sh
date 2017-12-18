#!/bin/bash

LIBRARY_NAME=${PKG_NAME//r-/}

if [[ $target_platform == osx-64 ]]; then
  FRAMEWORK=/Library/Frameworks/R.framework
  LIBRARY=$FRAMEWORK/Versions/3.4.1-MRO/Resources/library
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
