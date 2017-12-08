
#!/bin/bash

contains () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

make_mro_base () {
  if [[ $target_platform == osx-64 ]]; then
    FRAMEWORK=/Library/Frameworks/R.framework
    LIBRARY=$FRAMEWORK/Versions/3.4.1-MRO/Resources/library
  else
    FRAMEWORK=
    LIBRARY=$FRAMEWORK/library
  fi

  mkdir -p "$PREFIX"$LIBRARY

  pushd unpack$LIBRARY
    for LIBRARY_CASED in $(find . -iname "*" -maxdepth 1 -mindepth 1); do
      LIBRARY_CASED=${LIBRARY_CASED//.\//}
      if ! contains $LIBRARY_CASED "${EXCLUDED_PACKAGES[@]}"; then
        echo "Including $LIBRARY_CASED"
        mv $LIBRARY_CASED "$PREFIX"$LIBRARY/
      else
        echo "Skipping $LIBRARY_CASED"
      fi
    done
  popd

  pushd unpack
    mv bin/* "$PREFIX"/bin
    mv doc etc include modules share README.R* CHANGES COPYING README Tcl src "$PREFIX"
  popd
}
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
EXCLUDED_PACKAGES+=(R6)
EXCLUDED_PACKAGES+=(RevoIOQ)
EXCLUDED_PACKAGES+=(RevoMods)
EXCLUDED_PACKAGES+=(RevoUtils)
EXCLUDED_PACKAGES+=(RODBC)
EXCLUDED_PACKAGES+=(rpart)
EXCLUDED_PACKAGES+=(RUnit)
EXCLUDED_PACKAGES+=(spatial)
EXCLUDED_PACKAGES+=(survival)


make_mro_base
