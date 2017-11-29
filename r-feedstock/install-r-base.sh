#!/bin/bash

pushd unpack
  find . | sort > ${RECIPE_DIR}/r-base-mro.txt
popd
