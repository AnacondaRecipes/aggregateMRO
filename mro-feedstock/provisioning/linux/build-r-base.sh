#!/usr/bin/env bash

CROOT=/opt/conda
BROOT=/builddir
#BROOT=/tmp/r_build

#if [[ ! -d ${CROOT} ]]; then
#  wget https://repo.continuum.io/pkgs/misc/preview/Miniconda3-4.3.31-Linux-x86_64.sh && \
#       bash Miniconda3-4.3.31-Linux-x86_64.sh -bfp ${CROOT} && \
#       . ${CROOT}/bin/activate && \
#       conda install -y gcc_linux-64 gxx_linux-64 autoconf automake pkg-config libtool cmake make git perl gettext libuuid zlib
#else
#. ${CROOT}/bin/activate
#fi

mkdir -p ${BROOT}/target/R/Linux

pushd ${CONDA_PREFIX}/bin
  cp $CC cc
  cp $GCC gcc
  cp $GXX g++
  cp $GFORTRAN gfortran
  export CC=cc
  export GCC=gcc
  export GXX=g++
  export GFORTRAN=gfortran
  export G77=gfortran
popd

# checking for makeindex... no
# checking for texi2any... no
# configure: WARNING: you cannot build info or HTML versions of the R manuals
# checking for texi2dvi... no
# checking for kpsewhich... /builddir/vendor/build/bin/kpsewhich
# checking for latex inconsolata package... missing
# configure: WARNING: neither inconsolata.sty nor zi4.sty found: PDF vignettes and package manuals will not be rendered optimally

pushd ${BROOT}
  wget -c https://cran.r-project.org/src/base/R-3/R-3.4.1.tar.gz
  tar -xf R-3.4.1.tar.gz
  pushd R-3.4.1
  bash -x ./configure --verbose \
              --with-x=yes \
              --prefix=${BROOT}/target/R/Linux \
              --enable-R-shlib \
              --enable-BLAS-shlib \
              --enable-memory-profiling \
              --with-libpng \
              --with-ICU \
              --with-jpeglib \
              --disable-rpath \
              --with-tcltk \
              --with-tcl-config=/builddir/vendor/build/lib/tclConfig.sh \
              --with-tk-config=/builddir/vendor/build/lib/tkConfig.sh \
              TCLTK_LIBS="-pthread -lz -lX11 -lXft -ltcl8.6 -ltk8.6 -lz" \
              TCLTK_CPPFLAGS="-pthread" \
              PKG_CONFIG_PATH=/builddir/vendor/build/lib/pkgconfig \
              CFLAGS="-I/builddir/vendor/build/include -DU_STATIC_IMPLEMENTATION ${CFLAGS}" \
              LDFLAGS="-L/builddir/vendor/build/x86_64-conda_cos6-linux-gnu/sysroot/usr/lib64 -L/builddir/vendor/build/lib ${LDFLAGS}" \
              LIBS="-luuid -licui18n -licuuc -licudata -lstdc++" \
              CPPFLAGS="-I/builddir/vendor/build/include -DU_STATIC_IMPLEMENTATION ${CPPFLAGS}" \
              CXXFLAGS="-I/builddir/vendor/build/include -DU_STATIC_IMPLEMENTATION ${CXXFLAGS}"
  make -j24
  make install
  popd
popd
