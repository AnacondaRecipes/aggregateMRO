#!/bin/bash

[[ -f ${PREFIX}/bin/R.non-r-mrclient ]] && rm -f ${PREFIX}/bin/R.non-r-mrclient || true
mv ${PREFIX}/bin/R ${PREFIX}/bin/R.non-r-mrclient
ln -s ${PREFIX}/rclient/3.4.3/bin/R/R ${PREFIX}/bin/R
