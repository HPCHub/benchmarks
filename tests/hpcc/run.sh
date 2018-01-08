#!/bin/bash

if [ -f ../platform.sh ]; then
  . ../platform.sh
fi

. include.sh

HPCHUB_TEST_STATE=run

if [ -f "${HPCHUB_PLATFORM}" ]; then
  . ${HPCHUB_PLATFORM}
fi

cd hpcc-${hpcc_version}

cp ../hpccinf.txt ./

if [ -f "${HPCHUB_MACHINEFILE}" ];then
  cp "${HPCHUB_MACHINEFILE}" ./machinefile
else
  cp ../machinefile ./
fi

LogStep hpcc-noargs Start 

rm hpccoutf.txt 2>/dev/null  

${HPCHUB_MPIRUN} `pwd`/hpcc

${HPCHUB_MPIWAIT}

LogStep hpcc-noargs hpcc-all

NMPI=`grep -A 10 "Begin of MPIRandomAccess section." hpccoutf.txt | grep "GUP" | head -n 1 | awk '{print $1;};'` 

LogStep hpcc-noargs MPIRandomAccess $NMPI

NStar=`grep -A 10 "Begin of StarRandomAccess section." hpccoutf.txt | grep "GUP" | head -n 1 | awk '{print $1;};'` 

LogStep hpcc-noargs MPIRandomAccess $NStar

cd ..
