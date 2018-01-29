#!/bin/bash

if [[ $target_platform =~ linux.* ]] || [[ $target_platform == win-32 ]]; then
  export DISABLE_AUTOBREW=1
  mv DESCRIPTION DESCRIPTION.old
  grep -v '^Priority: ' DESCRIPTION.old > DESCRIPTION
  if [[ $target_paltform =~ linux.* ]]; then
    xvfb-run $R CMD INSTALL --build .
  else
    $R CMD INSTALL --build .
  fi
else
  mkdir -p $PREFIX/lib/R/library/rpanel
  mv * $PREFIX/lib/R/library/rpanel
fi
