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

cd osu-micro-benchmarks-${osu_version}

if [ -f "${HPCHUB_MACHINEFILE}" ];then
  cp "${HPCHUB_MACHINEFILE}" ./machinefile
else
  cp ../machinefile ./
fi

mkdir -p ../../runs/run/osu

MPIRUN=`echo $HPCHUB_MPIRUN | awk '{print $1}'`
MPIRUN= "`which $MPIRUN`"
if [ "`$MPIRUN --help | grep 'Open MPI'`" != "" ]; then
	MPIRUN_BIND='--bind-to core'
fi


LogStep osu Start 
cp machinefile machinefile_reserv
cat machinefile_reserv | uniq | head -n 2 > machinefile
$MPIRUN -np 2  -machinefile machinefile $MPIRUN_BIND ./osu/osu-micro-benchmarks-5.4/mpi/pt2pt/osu_latency -x 10000 -i 100000 -m 131072
mv machinefile_reserv  machinefile

LogStep osu latency
