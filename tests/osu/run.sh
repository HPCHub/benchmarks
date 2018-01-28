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

MPIRUN=`which mpirun`



LogStep osu Start 
iter=0
for h in $NODES; do
	if [ $iter -gt 1 ]; then 
		break
	fi
    echo $h >> machinefile
	let iter=iter+1
done

$MPIRUN -n 2  osu/osu-micro-benchmarks-5.4/mpi/pt2pt/osu_latency -x 10000 -i 100000 -m 131072 2>&1 | tee ../../runs/run/osu/osu_latency.out

LogStep osu latency
