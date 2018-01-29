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
MPIRUN="`which $MPIRUN`"
if [ "`$MPIRUN --help | grep 'Open MPI'`" != "" ]; then
	MPIRUN_BIND='--bind-to core'
	PPN='--npernode'
fi


LogStep osu Start 
cp machinefile machinefile_reserv
cat machinefile_reserv | uniq | head -n 2 > machinefile

runstr="$MPIRUN -np 2  -machinefile machinefile $MPIRUN_BIND $PPN 1 ./mpi/pt2pt/osu_latency -x 10000 -i 100000 -m 131072"
echo $runstr
eval $runstr
rm machinefile
LogStep osu latency

for i in `seq 1 $NCPU`; do
	for h in `echo $NODES | awk '{print $1 $2}'`; do
		for ppn in `seq 1 $i`; do
			echo $h >> machinefile
		done
	done
	runstr="$MPIRUN -np $((2*i))  -machinefile machinefile $MPIRUN_BIND $PPN $i ./mpi/pt2pt/osu_mbw_mr -V"
	echo $runstr
	eval $runstr
	LogStep osu mbw_mr $i
done 
