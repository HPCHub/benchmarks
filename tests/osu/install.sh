#!/bin/bash

if [ -f ../platform.sh ]; then
  . ../platform.sh
fi
. include.sh

HPCHUB_TEST_STATE=install

if [ -f "${HPCHUB_PLATFORM}" ]; then
  . ${HPCHUB_PLATFORM}
fi

if [ ! -f osu-micro-benchmarks-${osu_version}.tar.gz ]; then
  wget http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-${osu_version}.tar.gz 
  tar -xvzf osu-micro-benchmarks-${osu_version}.tar.gz
fi

cd osu-micro-benchmarks-${osu_version}

./configure --prefix=${HOME}/usr

make
make install
