#!/bin/bash

LIBRARY_NAME=${PKG_NAME//r-/}

LIBRARY=/lib/R/library
PREFIX_LIB="$PREFIX"/$LIBRARY

mkdir -p "$PREFIX_LIB"/MicrosoftML/mxLibs/x64/AutoLoad
pushd unpack/mlm-training-models/opt/microsoft/rclient/$PKG_VERSION/libraries/RServer/MicrosoftML/mxLibs/x64/AutoLoad || exit 1
  mv *.model "$PREFIX_LIB"/MicrosoftML/mxLibs/x64/AutoLoad/ || exit 1
popd

find . | wc -l
