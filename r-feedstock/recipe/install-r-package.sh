#!/bin/bash

LIBRARY_NAME=${PKG_NAME//r-/}

if [[ $target_platform == osx-64 ]]; then
  FRAMEWORK=/Library/Frameworks/R.framework
  LIBRARY=$FRAMEWORK/Versions/3.4.1-MRO/Resources/library
else
  FRAMEWORK=
  LIBRARY=$FRAMEWORK/library
fi

mkdir -p "$PREFIX"$LIBRARY

pushd unpack$LIBRARY
for LIBRARY_CASED in $(find . -iname "$LIBRARY_NAME" -maxdepth 1 -mindepth 1); do
  mv $LIBRARY_CASED "$PREFIX"$LIBRARY/
done
find . | wc -l
