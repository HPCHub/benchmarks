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


Tprev=`date +%s.%N`

function LogStep {
   ret=$?
   if [ "$ret" -gt "0" ]; then
      echo "Step $StepCntr failed"
      exit $ret
   else
      StepCntr=$((StepCntr+1))
   fi
   local T0=`date +%s.%N`
   dT=`echo "$T0 - $Tprev" | bc -l`
   echo -ne "${p}\t$1\t$dT\t$T0\n" >> $report_to
   Tprev=$T0
}

echo -ne "Protein\tStep\tdT\tTimeStamp\n" > $report_to

cd hpcc-${hpcc_version}

cp ../hpccinf.txt ./

cp ../machinefile ./

LogStep Start 

${HPCHUB_MPIRUN} `pwd`/hpcc

LogStep hpcc-all

cd ..
