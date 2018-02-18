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
  if [ -f ../machinefile ]; then cp ../machinefile ./ ; fi
fi

LogStep fio-noargs Start 

function getbw { 
  value=`cat job* | perl -e '$S=0;$N=0;while(<>){if(s/.*bw=(\d+.?\d*).*/$1/) { $S+=$_; $N++;} ; }; print $S/$N; '`
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

cp ../fiorun.sh ./
chmod a+x fiorun.sh

for size in 128m 4096m; do
for op in "read" "write" "randread" "randwrite" ; do
  rm job*
   
  ${HPCHUB_MPIRUN} `pwd`/fiorun.sh $op $size  
  ${HPCHUB_MPIWAIT}


  getbw

  LogStep fio-${size}-${op} BW $value

  getlat
  
  LogStep fio-${size}-${op} Latency.avg $value

done
done
cd ..
