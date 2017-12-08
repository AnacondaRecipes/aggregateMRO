
#!/bin/bash

if [[ $target_platform == win-64 ]]; then
  ARCHIVE=SRO_3.4.1.0_1033.cab
elif [[ $target_platform == linux-64 ]]; then
  ARCHIVE=microsoft-r-open-3.4.1.pkg
elif [[ $target_platform == osx-64 ]]; then
  ARCHIVE=microsoft-r-open-3.4.1.pkg
fi

# If conda-build used libarchive to unpack things this would not need to exist
mkdir -p unpack
pushd unpack
  if [[ -f ../$ARCHIVE ]]; then
    python -c "import libarchive, os; libarchive.extract_file('../$ARCHIVE')"
  fi
  # Even on Darwin, libarchive will fail to unpack a .pkg file.
  if [[ $? != 0 ]]; then
    xar -xf ../$ARCHIVE
    for PAYLOAD in $(find . -name Payload); do
      cat "$PAYLOAD" | gunzip -dc | cpio -i
    done
    rm -rf R_Open_App.pkg R_Open_Framework.pkg Distribution
  fi
  find . | sort > $RECIPE_DIR/filelist-mro-$target_platform.txt
popd
