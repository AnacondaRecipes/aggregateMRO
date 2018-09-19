#!/bin/bash

pushd $(mktemp -d)
  "$SRC_DIR"/innoextract/innoextract.exe "$SRC_DIR"/Rtools35.exe
  find .
  mkdir -p $PREFIX/Rtools/{bin,mingw_64,mingw_libs/lib/x64,mingw_libs/include,texinfo5}
  mv app/bin/* $PREFIX/Rtools/bin/
  mv app/mingw_64/* $PREFIX/Rtools/mingw_64/
  mv app/mingw_libs/lib/x64/* $PREFIX/Rtools/mingw_libs/lib/x64/
  mv app/mingw_libs/include/* $PREFIX/Rtools/mingw_libs/include/
  mv app/texinfo5 $PREFIX/Rtools/
  mv app/{COPYING,README.txt,Rtools.txt,VERSION.txt} $PREFIX/Rtools/
  mv 'code$rhome64'/Tcl/include/* $PREFIX/Rtools/mingw_libs/include/
  mv 'code$rhome64'/Tcl/lib64/* $PREFIX/Rtools/mingw_libs/lib/x64/
  mkdir -p $PREFIX/etc/conda/activate.d
  mkdir -p $PREFIX/etc/conda/deactivate.d
  cp "$RECIPE_DIR"/rtools-activate.bat $PREFIX/etc/conda/activate.d/
  cp "$RECIPE_DIR"/rtools-deactivate.bat $PREFIX/etc/conda/deactivate.d/
popd
