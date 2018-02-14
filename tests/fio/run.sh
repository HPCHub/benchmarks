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

cd ${fio_dir}

if [ -f "${HPCHUB_MACHINEFILE}" ];then
  cp "${HPCHUB_MACHINEFILE}" ./machinefile
else
  cp ../machinefile ./
fi

LogStep fio-noargs Start 

function getbw { 
  value=`cat job* | perl -e '$S=0;$N=0;while(<>){if(s/.*bw.?\d*).*/$1/) { $S+=$_; $N++;} ; }; print $S/$N; '`
  echo "getbw.value: $value"
  if [ "$value" = "" ]; then
    value="0.0";  
  fi; 
}

function getlat {
  
  value=`cat job* | perl -e '$S=0;$N=0;while(<>){if(s/.* lat.*avg=(\d+\.?\d*),.*/$1/) { $S+=$_; $N++;} ; }; print $S/$N;'`
  
  echo "getlat.value: $value"
  if [ "$value" = "" ]; then
    value="0.0";  
  fi; 
}

HPCHUB_PPN=1

for op in "read" "write" "randread" "randwrite" ; do
  rm job*
 
  ${HPCHUB_MPIRUN} `pwd`/fiorun.sh $op  
  ${HPCHUB_MPIWAIT}


  getbw

  LogStep fio-$op BW $value

  getlat
  
  LogStep fio-$op Latency.avg $value

done
cd ..
