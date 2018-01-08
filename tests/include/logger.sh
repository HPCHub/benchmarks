#!/bin/bash

###
#
#  This file is intended to be included from every
#  test plan. It contains unified procedures and 
#  operations required to organise logging facility of
#  various tests in consistent way.
#
###

if [ "${HPCHUB_REPORT}" = "" ]; then
  report_to=../report.time.txt
else
  report_to=${HPCHUB_REPORT}
fi


Tprev=`date +%s.%N`

###
#
# function LogStep accepts three arguments:
#
# 1 - Object name
# 2 - Step name
# 3 - Number of operations performed
#
# In current implementation it stores absolute time,
# time since previous invocation, 
#
###

function LogStep {
   ret=$?
   if [ "$ret" -gt "0" ]; then
      echo "Step $StepCntr failed"
      exit $ret
   else
      StepCntr=$((StepCntr+1))
   fi
   Nops=$3
   if [ "$Nops" = "" ]; then 
       Nops=1
   fi
   local T0=`date +%s.%N`
   dT=`echo "$T0 - $Tprev" | bc -l`
   echo -ne "$1\t$2\t$dT\t$T0\t$Nops\n" >> $report_to
   Tprev=$T0
}

echo -ne "Element\tStep\tdT\tTimeStamp\tNops\n" > $report_to


