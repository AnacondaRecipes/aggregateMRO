declare -a EXCLUDED_PACKAGES

EXCLUDED_PACKAGES+=(r-base)
EXCLUDED_PACKAGES+=(r-boot)
EXCLUDED_PACKAGES+=(r-checkpoint)
EXCLUDED_PACKAGES+=(r-class)
EXCLUDED_PACKAGES+=(r-cluster)
EXCLUDED_PACKAGES+=(r-codetools)
EXCLUDED_PACKAGES+=(r-curl)
EXCLUDED_PACKAGES+=(r-deployrrserve)
EXCLUDED_PACKAGES+=(r-doparallel)
EXCLUDED_PACKAGES+=(r-foreach)
EXCLUDED_PACKAGES+=(r-foreign)
EXCLUDED_PACKAGES+=(r-iterators)
EXCLUDED_PACKAGES+=(r-jsonlite)
EXCLUDED_PACKAGES+=(r-kernsmooth)
EXCLUDED_PACKAGES+=(r-lattice)
EXCLUDED_PACKAGES+=(r-mass)
EXCLUDED_PACKAGES+=(r-matrix)
EXCLUDED_PACKAGES+=(r-mgcv)
EXCLUDED_PACKAGES+=(r-microsoftr)
EXCLUDED_PACKAGES+=(r-nlme)
EXCLUDED_PACKAGES+=(r-nnet)
EXCLUDED_PACKAGES+=(r-png)
EXCLUDED_PACKAGES+=(r-r6)
EXCLUDED_PACKAGES+=(r-revoioq)
EXCLUDED_PACKAGES+=(r-revomods)
EXCLUDED_PACKAGES+=(r-revoutils)
EXCLUDED_PACKAGES+=(r-revoutilsmath)
EXCLUDED_PACKAGES+=(r-rpart)
EXCLUDED_PACKAGES+=(r-runit)
EXCLUDED_PACKAGES+=(r-spatial)
EXCLUDED_PACKAGES+=(r-survival)

pushd $(mktemp -d)
  python ~/conda/private_conda_recipes/rays-scratch-scripts/binstar_copy.py --owner rdonnellyr --platform linux-64 --operation download --dest $PWD --package-name "r-gsl*"
  declare -a tbzs
  tbzs=$(find $PWD -name *.tar.bz2)
  echo tbzs are:
  for tbz in ${tbzs[@]}; do
    echo $tbz
  done
popd
