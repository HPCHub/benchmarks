#!/bin/bash

if [ -f ../platform.sh ]; then
  . ../platform.sh
fi
. include.sh

HPCHUB_TEST_STATE=install

if [ -f "${HPCHUB_PLATFORM}" ]; then
  . ${HPCHUB_PLATFORM}
fi

if [ ! -f NPB${npb_version}.tar.gz ]; then
  wget https://www.nas.nasa.gov/assets/npb/NPB${npb_version}.tar.gz
  tar -xvzf NPB${npb_version}.tar.gz
fi

cd NPB${npb_version}

#./configure  CC=$CC CXX=$CXX FC=$FC
#--prefix=${HOME}/usr

make
#make install
