#!/bin/bash

if [[ $target_platform == win-64 ]]; then
  ARCHIVE=microsoft-r-client-packages-3.4.1.exe
elif [[ $target_platform == linux-64 ]]; then
  ARCHIVE=microsoft-r-client-packages-3.4.1.rpm
elif [[ $target_platform == osx-64 ]]; then
  ARCHIVE=microsoft-r-client-packages-3.4.1.pkg
fi

mkdir -p unpack
pushd unpack

  # 1. Finish unpacking.
  #    (if conda-build used libarchive to unpack things we could aim to remove this
  #     but it would need a metadata flag to unpack archives within archives too).
  declare -a ARCHIVES
  if [[ -f $ARCHIVE ]]; then
    if [[ $target_platform == win-64 ]]; then
      pushd $(mktemp -d)
        chmod +x "$SRC_DIR"/wix/dark.exe
        "$SRC_DIR"/wix/dark.exe $SRC_DIR/unpack/$ARCHIVE -x $PWD
        rm -f $SRC_DIR/unpack/$ARCHIVE
        msiexec -a $(cygpath -w $PWD/AttachedContainer/ROpen.msi) -qb TARGETDIR=$(cygpath -w "$PWD")
        mv Microsoft/MRO-$PKG_VERSION.0/Setup/MKL_2017.0.36.5_1033.cab "$SRC_DIR"/unpack
        mv Microsoft/MRO-$PKG_VERSION.0/Setup/MROPKGS_9.2.0.0_1033.cab "$SRC_DIR"/unpack
        # This contains VCRT_14.0.23026.0_1033.exe and RSetup.exe
        rm -rf Microsoft/MRO-$PKG_VERSION.0/Setup
        mkdir -p "$SRC_DIR"/unpack/lib
        mv Microsoft/MRO-$PKG_VERSION.0 "$SRC_DIR"/unpack/lib/R
        # msiexec -a $(cygpath -w $PWD/Microsoft/MRO-$PKG_VERSION.0/Setup/MKL_2017.0.36.5_1033.cab) -qb TARGETDIR=$(cygpath -w "$SRC_DUR"/unpack)
        # msiexec -a $(cygpath -w $PWD/Microsoft/MRO-$PKG_VERSION.0/Setup/MROPKGS_9.2.0.0_1033.cab) -qb TARGETDIR=$(cygpath -w "$SRC_DUR"/unpack)
        # TODO :: The MKL archive should probably be unpacked when during install-r-package.sh for RevoUtilsMath instead.
        ARCHIVES+=(MKL_2017.0.36.5_1033.cab,lib/R)
        ARCHIVES+=(MROPKGS_9.2.0.0_1033.cab,lib/R)
      popd
    elif [[ $target_platform == osx-64 ]]; then
      # https://github.com/libarchive/libarchive/issues/456
      xar -xf $ARCHIVE
      rm $ARCHIVE
      for PAYLOAD in $(find . -name Payload); do
        ARCHIVES+=($PAYLOAD,.)
      done
    else
      ARCHIVES+=($ARCHIVE,.)
    fi
    echo ARCHIVES are ${ARCHIVES[@]}
    for ARCHIVE_DEST in "${ARCHIVES[@]}"; do
      ARCHIVE=${ARCHIVE_DEST//,*/}
      DEST=${ARCHIVE_DEST#*,}
      if [[ "$DEST" != "." ]]; then
        mv $ARCHIVE $DEST/
      fi
      pushd $DEST
        python -c "import libarchive, os; libarchive.extract_file('$ARCHIVE')" || exit 1
        rm $ARCHIVE
      popd
    done
  fi
popd
