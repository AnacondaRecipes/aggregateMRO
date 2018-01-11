#!/bin/bash

LIBRARY_NAME=${PKG_NAME//r-/}

LIBRARY=/lib/R/library
PREFIX_LIB="$PREFIX"/$LIBRARY

mkdir -p "$PREFIX_LIB"

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
