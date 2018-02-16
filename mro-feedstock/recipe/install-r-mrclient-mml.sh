#!/bin/bash

LIBRARY_NAME=${PKG_NAME//r-/}

contains () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

declare -a R_CLIENT_ML_LIBRARIES
R_CLIENT_ML_LIBRARIES+=(MicrosoftML)

LIBRARY=/lib/R/library
PREFIX_LIB="$PREFIX"/$LIBRARY

mkdir -p "$PREFIX_LIB"

pushd unpack$LIBRARY || exit 1
  for LIBRARY_CASED in $(find . -iname "*" -maxdepth 1 -mindepth 1); do
    LIBRARY_CASED=${LIBRARY_CASED//.\//}
    if contains $LIBRARY_CASED "${R_CLIENT_ML_LIBRARIES[@]}"; then
      echo "Including $LIBRARY_CASED in $LIBRARY_NAME => $PREFIX_LIB"
      mv $LIBRARY_CASED "$PREFIX_LIB"/
    else
      echo "Excluding $LIBRARY_CASED from $LIBRARY_NAME"
    fi
  done
popd

find . | wc -l
