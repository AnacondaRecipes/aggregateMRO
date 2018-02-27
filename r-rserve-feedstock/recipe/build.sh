#!/bin/bash

# This package makes a standalone binary and needs to find libraries essential to R.
# It is likely that src/Makevars.in should use $(MAIN_LINK) from lib/R/etc/Makeconf
# for this instead of having to pass it in via the PKG_LIBS environment variable.
if [[ ${HOST} =~ .*darwin.* ]]; then
  PKG_LIBS="-L${PREFIX}/lib" $R CMD INSTALL --build .
else
  # .. on Linux the situation is even worse:
  PKG_LIBS="-L${PREFIX}/lib -L${PREFIX}/lib/R/lib -lR -Wl,-rpath-link,${PREFIX}/lib -lRblas" \
    $R CMD INSTALL --build .
fi
