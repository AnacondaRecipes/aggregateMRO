#!/bin/bash

LIBRARY_NAME=${PKG_NAME//r-/}

if [[ $target_platform == osx-64 ]]; then
  FRAMEWORK=/Library/Frameworks/R.framework
  LIBRARY=$FRAMEWORK/Versions/3.4.1-MRO/Resources/library
elif [[ $target_platform == win-64 ]]; then
  FRAMEWORK=
  LIBRARY=$FRAMEWORK/library
else
  LIBRARY=$FRAMEWORK/lib/R/library
  PREFIX_LIB="$PREFIX"/library
fi

mkdir -p "$PREFIX"$LIBRARY

if [[ "$LIBRARY_NAME" == "revoutilsmath" ]] && [[ $target_platform == linux-64 ]]; then
  mkdir -p "$PREFIX"/lib/mro_mkl/
  mv unpack/lib/mro_mkl/* "$PREFIX"/lib/mro_mkl/
  mv "$PREFIX"/lib/mro_mkl/libRblas.so "$PREFIX"/lib/
fi

pushd unpack$LIBRARY || exit 1
  for LIBRARY_CASED in $(find . -iname "$LIBRARY_NAME" -maxdepth 1 -mindepth 1); do
    mv $LIBRARY_CASED "$PREFIX_LIB"/
  done
popd

find . | wc -l
