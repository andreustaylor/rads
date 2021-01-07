set -euax 
# what: basic build for NCI
# note: probably not the best way to include netcdf paths ...hardcoded to match module   

# modules
module load netcdf/4.7.3
module load intel-compiler/2020.1.217

# working path
RADS=$(pwd) # eg /g/data/ep4/altimetry/rads
cd $RADS

# build
./configure --bindir ${RADS}/bin/ --with-netcdf-inc=/apps/netcdf/4.7.3/include/ --with-netcdf-lib=/apps/netcdf/4.7.3/lib/
make install

