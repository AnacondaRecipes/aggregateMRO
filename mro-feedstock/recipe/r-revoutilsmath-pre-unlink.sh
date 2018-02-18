#!/bin/sh

rm $PREFIX/lib/R/lib/libRblas.so || exit 1
rm $PREFIX/lib/R/lib/libRlapack.so || exit 2
cp $PREFIX/lib/R/lib/libRblas.so.nomkl $PREFIX/lib/R/lib/libRblas.so || exit 3
cp $PREFIX/lib/R/lib/libRlapack.so.nomkl $PREFIX/lib/R/lib/libRlapack.so || exit 4
