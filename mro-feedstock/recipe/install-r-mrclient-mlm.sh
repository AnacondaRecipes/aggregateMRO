#!/bin/bash

LIBRARY_NAME=${PKG_NAME//r-/}

LIBRARY=/lib/R/library
PREFIX_LIB="$PREFIX"/$LIBRARY

# This will probably already exist since RClient has some stuff in here
mkdir -p "$PREFIX_LIB"/MicrosoftML/mxLibs/x64/AutoLoad
pushd unpack-r-client-mlm/opt/microsoft/rclient/$PKG_VERSION/libraries/RServer/MicrosoftML/mxLibs/x64/AutoLoad
  mv *.model "$PREFIX_LIB"/MicrosoftML/mxLibs/x64/AutoLoad/
popd

find . | wc -l
