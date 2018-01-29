#!/bin/bash

if [[ $target_platform =~ linux.* ]] || [[ $target_platform == win-32 ]]; then
  # Filter out -std=.* from CXXFLAGS as it disrupts checks for C++ language levels.
  re='(.*[[:space:]])\-std\=[^[:space:]]*(.*)'
  if [[ "${CXXFLAGS}" =~ $re ]]; then
    export CXXFLAGS="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
  fi
  export DISABLE_AUTOBREW=1
  mv DESCRIPTION DESCRIPTION.old
  grep -v '^Priority: ' DESCRIPTION.old > DESCRIPTION
  $R CMD INSTALL --build .
else
  mkdir -p $PREFIX/lib/R/library/RJSONIO
  mv * $PREFIX/lib/R/library/RJSONIO
fi
