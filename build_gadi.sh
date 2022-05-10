set -euax 
# what: basic build for NCI
# manual recommends gfortran
module unload gcc
module load gcc/11.1.0

NCVER=4.7.3
module unload netcdf
module load netcdf/${NCVER}

# working path
RADS=$(pwd) # eg /g/data/ep4/altimetry/rads
cd $RADS

# fixed path for where RADS database is sync
DATA=/g/data/ep4/altimetry/data

# build
make clean
./configure  --enable-debug --datarootdir ${DATA}
make install

