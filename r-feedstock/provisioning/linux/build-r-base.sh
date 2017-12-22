#!/usr/bin/env bash

CROOT=/opt/conda_r
BROOT=${HOME}/r_build
#BROOT=/tmp/r_build

if [[ ! -d ${CROOT} ]]; then
  wget https://repo.continuum.io/pkgs/misc/preview/Miniconda3-4.3.31-Linux-x86_64.sh && \
       bash Miniconda3-4.3.31-Linux-x86_64.sh -bfp ${CROOT} && \
       . ${CROOT}/bin/activate && \
       conda install -y gcc_linux-64 gxx_linux-64 autoconf automake pkg-config libtool cmake make git perl gettext libuuid zlib
else
. ${CROOT}/bin/activate
fi

pushd ${BROOT}
  wget -c 
popd
