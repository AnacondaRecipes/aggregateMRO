#!/bin/bash

if [[ $target_platform =~ linux.* ]] || [[ $target_platform == win-32 ]]; then
  export DISABLE_AUTOBREW=1
  mv DESCRIPTION DESCRIPTION.old
  grep -v '^Priority: ' DESCRIPTION.old > DESCRIPTION
  $R CMD INSTALL --build .
else
  mkdir -p $PREFIX/lib/R/library/xml2
  for SHARED_LIB in $(find . -type f -iname "*.dylib" -or -iname "*.so"); do
    echo "fixing SHARED_LIB $SHARED_LIB"
    set -x
    install_name_tool -change /Library/Frameworks/R.framework/Versions/3.5/Resources/lib/libR.dylib "$PREFIX"/lib/R/lib/libR.dylib $SHARED_LIB || true
    install_name_tool -change /usr/local/clang4/lib/libomp.dylib "$PREFIX"/lib/libomp.dylib $SHARED_LIB || true
    install_name_tool -change /usr/local/gfortran/lib/libgfortran.3.dylib "$PREFIX"/lib/libgfortran.3.dylib $SHARED_LIB || true
    install_name_tool -change /usr/local/gfortran/lib/libquadmath.0.dylib "$PREFIX"/lib/libquadmath.0.dylib $SHARED_LIB || true
    install_name_tool -change /usr/lib/libgcc_s.1.dylib "$PREFIX"/lib/libgcc_s.1.dylib $SHARED_LIB || true
    install_name_tool -change /usr/lib/libiconv.2.dylib "$PREFIX"/sysroot/usr/lib/libiconv.2.dylib $SHARED_LIB || true
    install_name_tool -change /usr/lib/libncurses.5.4.dylib "$PREFIX"/sysroot/usr/lib/libncurses.5.4.dylib $SHARED_LIB || true
    install_name_tool -change /usr/lib/libicucore.A.dylib "$PREFIX"/sysroot/usr/lib/libicucore.A.dylib $SHARED_LIB || true
    install_name_tool -change /usr/lib/libexpat.1.dylib "$PREFIX"/lib/libexpat.1.dylib $SHARED_LIB || true
    install_name_tool -change /usr/lib/libcurl.4.dylib "$PREFIX"/lib/libcurl.4.dylib $SHARED_LIB || true
    install_name_tool -change /usr/lib/libc++.1.dylib "$PREFIX"/lib/libc++.1.dylib $SHARED_LIB || true
    install_name_tool -change /Library/Frameworks/R.framework/Versions/3.5/Resources/lib/libc++.1.dylib "$PREFIX"/lib/libc++.1.dylib $SHARED_LIB || true
    install_name_tool -change /usr/lib/libz.1.dylib "$PREFIX"/lib/libz.1.dylib $SHARED_LIB || true
    install_name_tool -change /usr/lib/libxml2.2.dylib "$PREFIX"/lib/libxml2.2.dylib $SHARED_LIB || true
  done
  mv * $PREFIX/lib/R/library/xml2
fi
