#!/usr/bin/env bash

mkdir -p $(dirname ${BASH_SOURCE[0]})/350-release-filelists
pushd $(dirname ${BASH_SOURCE[0]})/350-release-filelists
  python ~/conda/private_conda_recipes/rays-scratch-scripts/binstar_copy.py --owner mro_test --platform linux-64 --operation list > mro_test-linux-64.txt
  python ~/conda/private_conda_recipes/rays-scratch-scripts/binstar_copy.py --owner mro_test --platform win-64 --operation list > mro_test-win-64.txt
  python ~/conda/private_conda_recipes/rays-scratch-scripts/binstar_copy.py --owner rdonnellyr --platform linux-64 --operation list > rdonnellyr-linux-64.txt
  python ~/conda/private_conda_recipes/rays-scratch-scripts/binstar_copy.py --owner rdonnellyr --platform linux-32 --operation list > rdonnellyr-linux-32.txt
  python ~/conda/private_conda_recipes/rays-scratch-scripts/binstar_copy.py --owner rdonnellyr --platform win-64 --operation list > rdonnellyr-win-64.txt
  python ~/conda/private_conda_recipes/rays-scratch-scripts/binstar_copy.py --owner rdonnellyr --platform win-32 --operation list > rdonnellyr-win-32.txt
  python ~/conda/private_conda_recipes/rays-scratch-scripts/binstar_copy.py --owner rdonnellyr --platform osx-64 --operation list > rdonnellyr-osx-64.txt
popd

