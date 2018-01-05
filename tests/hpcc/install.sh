#!/bin/bash

if [ -f ../platform.sh ]; then
  . ../platform.sh
fi

HPCHUB_TEST_STATE=install

if [ -f "${HPCHUB_PLATFORM}" ]; then
  . ${HPCHUB_PLATFORM}
fi

hpcc_version=1.5.0b

if [ ! -f hpcc-${hpcc_version}.tar.gz ]; then
  wget http://icl.cs.utk.edu/projectsfiles/hpcc/download/hpcc-${hpcc_version}.tar.gz
  tar -xvzf hpcc-${hpcc_version}.tar.gz
fi

cd hpcc-${hpcc_version}

cp ../Make.hpchub hpl/Make.hpchub

make arch=hpchub

