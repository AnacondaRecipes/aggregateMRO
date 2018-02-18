#!/bin/sh

rm $PREFIX/lib/R/lib/libRblas.so || exit 1
rm $PREFIX/lib/R/lib/libRlapack.so || exit 2
cp $PREFIX/lib/R/lib/libRblas.so.mkl $PREFIX/lib/R/lib/libRblas.so || exit 3
cp $PREFIX/lib/R/lib/libRlapack.so.mkl $PREFIX/lib/R/lib/libRlapack.so || exit 4
