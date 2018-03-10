#!/usr/bin/env bash

VER=3.4.3
mkdir -p ~/conda/aggregateMRO/filelists-${VER}
pushd ~/conda/aggregateMRO/filelists-${VER}
  for PLATFORM in win-32 win-64 linux-32 linux-64 osx-64; do
    python ~/conda/private_conda_recipes/rays-scratch-scripts/binstar_copy.py --owner r --package-name '*r343*' --platform $PLATFORM --operation list > rdonnellyr-${PLATFORM}.txt
  done
  for PLATFORM in win-64 linux-64; do
    python ~/conda/private_conda_recipes/rays-scratch-scripts/binstar_copy.py --owner r --package-name '*mro343*' --platform $PLATFORM --operation list > mro_test-${PLATFORM}.txt
  done
popd
