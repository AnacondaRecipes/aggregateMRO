#!/bin/bash

LIBRARY_NAME=${PKG_NAME//r-/}

LIBRARY=/lib/R/library
PREFIX_LIB="$PREFIX"/$LIBRARY

mkdir -p "$PREFIX_LIB"/MicrosoftML/mxLibs/x64/AutoLoad
pushd unpack/mlm-training-models/opt/microsoft/rclient/$PKG_VERSION/libraries/RServer/MicrosoftML/mxLibs/x64/AutoLoad || exit 1
  for MODEL in $(find . -name "*.model" | cut -c 3-); do
    mv $MODEL "$PREFIX_LIB"/MicrosoftML/mxLibs/x64/$MODEL
    # Let us see how well symlinks work on Windows. We do not need the symlink to be a
    # symlink or to even exist we just need conda not to fall over on them at any point.
    # On Linux they need to work properly though since MicrosoftML looks in AutoLoad for
    # some reason.
    pushd "$PREFIX_LIB"/MicrosoftML/mxLibs/x64/AutoLoad
      ln -s ../$MODEL $MODEL
    popd
  done
popd

find . | wc -l
