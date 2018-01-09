#!/bin/bash

if [ -f ../platform.sh ]; then
  . ../platform.sh
fi

. include.sh

HPCHUB_TEST_STATE=run

if [ -f "${HPCHUB_PLATFORM}" ]; then
  . ${HPCHUB_PLATFORM}
fi

if [ "${HPCHUB_REPORT}" = "" ]; then
  report_to=../report.time.txt
else
  report_to=${HPCHUB_REPORT}
fi

. ../include/logger.sh

cd hpcc-${hpcc_version}

cp ../hpccinf.txt ./

if [ -f "${HPCHUB_MACHINEFILE}" ];then
  cp "${HPCHUB_MACHINEFILE}" ./machinefile
else
  cp ../machinefile ./
fi

LogStep hpcc-noargs Start 


for i in 1000 5000 10000 50000 100000; do
  
  rm hpccoutf.txt 2>/dev/null  

  s=`printf "%-13d%s" $i Ns` 

  cat ../hpccinf.txt | sed "s/1000         Ns/$s/" > hpccinf.txt

  ${HPCHUB_MPIRUN} `pwd`/hpcc 

  ${HPCHUB_MPIWAIT}

  LogStep hpcc-N-$i hpcc-all

  NMPI=`grep -A 10 "Begin of MPIRandomAccess section." hpccoutf.txt | grep "GUP" | head -n 1 | awk '{print $1;};'` 

  LogStep hpcc-N-$i MPIRandomAccess $NMPI

  NStar=`grep -A 10 "Begin of StarRandomAccess section." hpccoutf.txt | grep "GUP" | head -n 1 | awk '{print $1;};'` 

  LogStep hpcc-N-$i MPIRandomAccess $NStar

done

cd ..
