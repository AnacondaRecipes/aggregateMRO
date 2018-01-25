#!/bin/bash

[[ -f ${PREFIX}/bin/R.non-r-client ]] && rm -f ${PREFIX}/bin/R.non-r-client || true
mv ${PREFIX}/bin/R ${PREFIX}/bin/R.non-r-client
ln -s ${PREFIX}/rclient/3.4.1/bin/R ${PREFIX}/bin/R
