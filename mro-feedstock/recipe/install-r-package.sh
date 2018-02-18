#!/bin/bash

LIBRARY_NAME=${PKG_NAME//r-/}

LIBRARY=/lib/R/library
PREFIX_LIB="$PREFIX"/$LIBRARY

mkdir -p "$PREFIX_LIB"

if [[ "$LIBRARY_NAME" == "revoutilsmath" ]]; then
  if [[ $target_platform == linux-64 ]]; then
    mkdir -p "$PREFIX"/lib/R/lib/mro_mkl/
    mv unpack/lib/R/lib/mro_mkl/* "$PREFIX"/lib/R/lib/mro_mkl/
    mv "$PREFIX"/lib/R/lib/libRblas.so "$PREFIX"/lib/R/lib/libRblas.so.nomkl
    mv "$PREFIX"/lib/R/lib/libRlapack.so "$PREFIX"/lib/R/lib/libRlapack.so.nomkl
    mv "$PREFIX"/lib/R/lib/mro_mkl/libRblas.so "$PREFIX"/lib/R/lib/libRblas.so.mkl
    mv "$PREFIX"/lib/R/lib/mro_mkl/libRlapack.so "$PREFIX"/lib/R/lib/libRlapack.so.mkl
  elif [[ $target_platform == win-64 ]]; then
    LIBRARY=/lib/R.mkl/library
    mv "$PREFIX_LIB"/../bin/x64/Rblas.dll "$PREFIX_LIB"/../bin/x64/Rblas.dll.nomkl
    mv "$PREFIX_LIB"/../bin/x64/Rlapack.dll "$PREFIX_LIB"/../bin/x64/Rlapack.dll.nomkl
    mv unpack$LIBRARY/../bin/x64/Rblas.dll "$PREFIX_LIB"/../bin/x64/Rblas.dll.mkl
    mv unpack$LIBRARY/../bin/x64/Rlapack.dll "$PREFIX_LIB"/../bin/x64/Rlapack.dll.mkl
  fi
fi

pushd unpack$LIBRARY || exit 1
  for LIBRARY_CASED in $(find . -iname "$LIBRARY_NAME" -maxdepth 1 -mindepth 1); do
    if [[ $target_platform == osx-64 ]]; then
      # Un-framework-ification.
      for SHARED_LIB in $(find $LIBRARY_CASED . -iname "*.dylib" -or -iname "*.so"); do
        install_name_tool -change /Library/Frameworks/R.framework/Versions/3.4.3-MRO/Resources/lib/libR.dylib "$PREFIX"/lib/R/lib/libR.dylib $SHARED_LIB || true
        install_name_tool -change /usr/local/clang4/lib/libomp.dylib "$PREFIX"/lib/libomp.dylib $SHARED_LIB || true
      done
    fi
    mv $LIBRARY_CASED "$PREFIX_LIB"/
  done
popd

find . | wc -l
