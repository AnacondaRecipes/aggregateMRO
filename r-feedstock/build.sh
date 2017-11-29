#!/bin/bash

# If conda-build used libarchive to unpack things this would not need to exist
mkdir -p unpack
pushd unpack
  if [[ -f ../SRO_3.4.1.0_1033.cab ]]; then
    python -c 'import libarchive, os; libarchive.extract_file("../SRO_3.4.1.0_1033.cab")'
  elif [[ -f ../microsoft-r-open-3.4.1.pkg ]]; then
    python -c 'import libarchive, os; libarchive.extract_file("../microsoft-r-open-3.4.1.pkg")'
  fi
popd
