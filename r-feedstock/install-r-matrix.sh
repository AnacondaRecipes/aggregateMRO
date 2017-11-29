#!/bin/bash

if [[ ${target_platform} == osx-64 ]]; then
  FRAMEWORK=/Library/Frameworks/R.framework
  LIBRARY=${FRAMEWORK}/Versions/${PKG_VERSION}-MRO/Resources/library
else
  FRAMEWORK=
  LIBRARY=${FRAMEWORK}/library
fi

mkdir -p "${PREFIX}"${LIBRARY}
mv unpack"${LIBRARY}"/Matrix "${PREFIX}"${LIBRARY}/
