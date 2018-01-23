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

function getvalue {  
  local section=$1 
  local pattern=$2 
  local target=$3 
  local line="grep -A 20 \"$section\" hpccoutf.txt | awk '/$pattern/{print \$$target; };'"
  value=`bash -c "$line"`
  echo "value: $value"
  if [ "$value" = "" ]; then
    value="0.0";  
  fi; 
}

for i in 1000 5000 10000 50000 100000; do
  
  rm hpccoutf.txt 2>/dev/null  

  s=`printf "%-13d%s" $i Ns` 

  cat ../hpccinf.txt | sed "s/1000         Ns/$s/" > hpccinf.txt

  ${HPCHUB_MPIRUN} `pwd`/hpcc 

  ${HPCHUB_MPIWAIT}

  LogStep hpcc-N-$i hpcc-all

  NMPI=`grep -A 10 "Begin of MPIRandomAccess section." hpccoutf.txt | grep "GUP" | head -n 1 | awk '{print $1;};'` 

  if [ "$NMPI" = "" ]; then NMPI="0.0"; fi

  LogStep hpcc-N-$i MPIRandomAccess $NMPI

  NStar=`grep -A 10 "Begin of StarRandomAccess section." hpccoutf.txt | grep "GUP" | head -n 1 | awk '{print $1;};'` 

  if [ "$NStar" = "" ]; then NStar="0.0"; fi


  LogStep hpcc-N-$i StarRandomAccess $NStar

  cat hpccoutf.txt

  getvalue "Begin of StarDGEMM section" "Average" "3"

  LogStep hpcc-N-$i StarDGEMM_Average_Gflops $value

  getvalue "Begin of MPIFFT section" "^Gflop" "2"

  LogStep hpcc-N-$i MPIFFT_Gflops $value

  getvalue "Begin of StarFFT section" "Average Gflop" "3"

  LogStep hpcc-N-$i StarFFT_Average_Gflops $value

  getvalue "WR11C2R4" "WR11C2R4" "7"

  LogStep hpcc-N-$i "HPL_Gflops" $value

done
cd ..
