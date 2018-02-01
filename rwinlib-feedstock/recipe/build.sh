#!/bin/bash

find .
rm -rf extsoft/lib/i386
set -x
mv cairo/lib/x64/* extsoft/lib/x64/
mv cairo/include/* extsoft/include/
mv libcurl/lib/x64/* extsoft/lib/x64/
mv libcurl/include/* extsoft/include/
mkdir $PREFIX/Rtools
mv extsoft $PREFIX/Rtools
