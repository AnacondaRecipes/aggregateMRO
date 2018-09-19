#!/bin/bash

if [[ -f DESCRIPTION ]]; then
  export DISABLE_AUTOBREW=1
  mv DESCRIPTION DESCRIPTION.old
  grep -v '^Priority: ' DESCRIPTION.old > DESCRIPTION
  $R CMD INSTALL --build .
else
  mkdir -p $PREFIX/lib/R/library/Rcpp
  mv * $PREFIX/lib/R/library/Rcpp
fi
