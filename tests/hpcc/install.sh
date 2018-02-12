#!/bin/bash

if [ -f ../platform.sh ]; then
  . ../platform.sh
fi
. include.sh

HPCHUB_TEST_STATE=install

if [ -f "${HPCHUB_PLATFORM}" ]; then
  . ${HPCHUB_PLATFORM}
fi

if [ ! -f hpcc-${hpcc_version}.tar.gz ]; then
  wget http://icl.cs.utk.edu/projectsfiles/hpcc/download/hpcc-${hpcc_version}.tar.gz
  tar -xvzf hpcc-${hpcc_version}.tar.gz
fi

cd hpcc-${hpcc_version}

cp ../Make.hpchub hpl/Make.hpchub

${HPCHUB_COMPILE_PREFIX} make arch=hpchub

