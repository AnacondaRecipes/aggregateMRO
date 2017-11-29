#!/bin/bash

# If conda-build used libarchive to unpack things this would not need to exist
mkdir -p unpack
pushd unpack
  if [[ -f ../SRO_${PKG_VERSION}.0_1033.cab ]]; then
    python -c 'import libarchive, os; libarchive.extract_file("../SRO_3.4.1.0_1033.cab")'
  elif [[ -f ../microsoft-r-open-${PKG_VERSION}.pkg ]]; then
    if [[ $(uname) == Darwin ]]; then
      xar -xf ../microsoft-r-open-${PKG_VERSION}.pkg
      for PAYLOAD in $(find . -name Payload); do
        cat "${PAYLOAD}" | gunzip -dc | cpio -i
      done
      rm -rf R_Open_App.pkg R_Open_Framework.pkg Distribution
    else
      # libarchive cannot handle this file unfortunately, not even on macOS itself.
      python -c 'import libarchive, os; libarchive.extract_file("../microsoft-r-open-3.4.1.pkg")'
    fi
  fi
  find . | sort > ${RECIPE_DIR}/filelist-mro-${target_platform}.txt
popd
