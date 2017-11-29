#!/bin/bash

contains () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# Libraries in the superset of both ours and MRO:
# base, boot, checkpoint, class, cluster, codetools, compiler, curl, datasets, deployrRserve, doParallel, foreign, graphics, grDevices, grid, jsonlite, KernSmooth, lattice, MASS, Matrix, methods, mgcv, MicrosoftR, nlme, nnet, parallel, png, R6, RevoIOQ, RevoMods, RODBC, rpart, RUnit, spatial, splines, stats, stats4, survival, tcltk, tools, translations, utils
# Libraries in ours:
# base,                                              compiler,       datasets,                                     graphics, grDevices, grid,                                              methods,                               parallel,                                                           splines, stats, stats4,           tcltk, tools, translations, utils
declare -a EXCLUDED_PACKAGES
EXCLUDED_PACKAGES+=(boot)
EXCLUDED_PACKAGES+=(checkpoint)
EXCLUDED_PACKAGES+=(class)
EXCLUDED_PACKAGES+=(cluster)
EXCLUDED_PACKAGES+=(codetools)
EXCLUDED_PACKAGES+=(curl)
EXCLUDED_PACKAGES+=(deployrRserve)
EXCLUDED_PACKAGES+=(doParallel)
EXCLUDED_PACKAGES+=(foreign)
EXCLUDED_PACKAGES+=(jsonlite)
EXCLUDED_PACKAGES+=(KernSmooth)
EXCLUDED_PACKAGES+=(lattice)
EXCLUDED_PACKAGES+=(MASS)
EXCLUDED_PACKAGES+=(Matrix)
EXCLUDED_PACKAGES+=(mgcv)
EXCLUDED_PACKAGES+=(MicrosoftR)
EXCLUDED_PACKAGES+=(nlme)
EXCLUDED_PACKAGES+=(nnet)
EXCLUDED_PACKAGES+=(png)
EXCLUDED_PACKAGES+=(RevoIOQ)
EXCLUDED_PACKAGES+=(RevoMods)
EXCLUDED_PACKAGES+=(RODBC)
EXCLUDED_PACKAGES+=(rpart)
EXCLUDED_PACKAGES+=(RUnit)
EXCLUDED_PACKAGES+=(spatial)
EXCLUDED_PACKAGES+=(survival)
if [[ ${target_platform} == osx-64 ]]; then
  FRAMEWORK=/Library/Frameworks/R.framework
  LIBRARY=${FRAMEWORK}/Versions/${PKG_VERSION}-MRO/Resources/library
else
  FRAMEWORK=
  LIBRARY=${FRAMEWORK}/library
fi

mkdir -p "${PREFIX}"${LIBRARY}

pushd unpack"${LIBRARY}"
  for LIBRARY_CASED in $(find . -iname "*" -maxdepth 1 -mindepth 1); do
    LIBRARY_CASED=${LIBRARY_CASED//.\//}
    if ! contains ${LIBRARY_CASED} "${EXCLUDED_PACKAGES[@]}"; then
      mv ${LIBRARY_CASED} "${PREFIX}"${LIBRARY}/
    fi
  done
popd

pushd unpack
  mv bin/* "${PREFIX}"
  mv doc etc include modules share README.R* "${PREFIX}"
popd
