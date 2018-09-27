#!/bin/bash
set -x
if [[ $target_platform =~ linux.* ]] || [[ $target_platform == win-32 ]]; then
  # || [[ $target_platform == osx-64 ]]; then
  # 'Autobrew' is being used by more and more packages these days
  # to grab static libraries from Homebrew bottles. These bottles
  # are fetched via Homebrew's --force-bottle option which grabs
  # a bottle for the build machine which may not be macOS 10.9.
  # Also, we want to use conda packages (and shared libraries) for
  # these 'system' dependencies. See:
  # https://github.com/jeroen/autobrew/issues/3
  export DISABLE_AUTOBREW=1

  # R refuses to build packages that mark themselves as Priority: Recommended
  mv DESCRIPTION DESCRIPTION.old
  grep -v '^Priority: ' DESCRIPTION.old > DESCRIPTION
  if [[ $target_platform =~ linux.* ]]; then
    DISPLAY=${DISPLAY:-:0} \
      xvfb-run $R CMD INSTALL --build .
  else
    DISPLAY=${DISPLAY:-:0} \
      $R CMD INSTALL --build .
  fi
  # Add more build steps here, if they are necessary.

  # See
  # http://docs.continuum.io/conda/build.html
  # for a list of environment variables that are set during the build process.
else
  mkdir -p $PREFIX/lib/R/library/tkrplot
  mv * $PREFIX/lib/R/library/tkrplot

  if [[ $target_platform == osx-64 ]]; then
    pushd $PREFIX
      for libdir in lib/R/lib lib/R/modules lib/R/library lib/R/bin/exec sysroot/usr/lib; do
        pushd $libdir || exit 1
          for SHARED_LIB in $(find . -type f -iname "*.dylib" -or -iname "*.so" -or -iname "R"); do
            echo "fixing SHARED_LIB $SHARED_LIB"
            install_name_tool -change /Library/Frameworks/R.framework/Versions/3.5.0-MRO/Resources/lib/libR.dylib "$PREFIX"/lib/R/lib/libR.dylib $SHARED_LIB || true
            install_name_tool -change /Library/Frameworks/R.framework/Versions/3.5/Resources/lib/libR.dylib "$PREFIX"/lib/R/lib/libR.dylib $SHARED_LIB || true
            install_name_tool -change /usr/local/clang4/lib/libomp.dylib "$PREFIX"/lib/libomp.dylib $SHARED_LIB || true
            install_name_tool -change /usr/local/gfortran/lib/libgfortran.3.dylib "$PREFIX"/lib/libgfortran.3.dylib $SHARED_LIB || true
            install_name_tool -change /Library/Frameworks/R.framework/Versions/3.5/Resources/lib/libquadmath.0.dylib "$PREFIX"/lib/libquadmath.0.dylib $SHARED_LIB || true
            install_name_tool -change /usr/local/gfortran/lib/libquadmath.0.dylib "$PREFIX"/lib/libquadmath.0.dylib $SHARED_LIB || true
            install_name_tool -change /Library/Frameworks/R.framework/Versions/3.5/Resources/lib/libgfortran.3.dylib "$PREFIX"/lib/libgfortran.3.dylib $SHARED_LIB || true
            install_name_tool -change /usr/lib/libgcc_s.1.dylib "$PREFIX"/lib/libgcc_s.1.dylib $SHARED_LIB || true
            install_name_tool -change /usr/lib/libiconv.2.dylib "$PREFIX"/sysroot/usr/lib/libiconv.2.dylib $SHARED_LIB || true
            install_name_tool -change /usr/lib/libncurses.5.4.dylib "$PREFIX"/sysroot/usr/lib/libncurses.5.4.dylib $SHARED_LIB || true
            install_name_tool -change /usr/lib/libicucore.A.dylib "$PREFIX"/sysroot/usr/lib/libicucore.A.dylib $SHARED_LIB || true
            install_name_tool -change /usr/lib/libexpat.1.dylib "$PREFIX"/lib/libexpat.1.dylib $SHARED_LIB || true
            install_name_tool -change /usr/lib/libcurl.4.dylib "$PREFIX"/lib/libcurl.4.dylib $SHARED_LIB || true
            install_name_tool -change /usr/lib/libc++.1.dylib "$PREFIX"/lib/libc++.1.dylib $SHARED_LIB || true
            install_name_tool -change /Library/Frameworks/R.framework/Versions/3.5/Resources/lib/libc++.1.dylib "$PREFIX"/lib/libc++.1.dylib $SHARED_LIB || true
          done
        popd
      done
    popd
  fi
fi
