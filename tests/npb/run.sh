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

cd NPB${npb_version}/NPB3.3-MPI

if [ -f "${HPCHUB_MACHINEFILE}" ];then
  cp "${HPCHUB_MACHINEFILE}" ./machinefile
else
  cp ../../machinefile ./
fi

mkdir -p ../../../runs/run/npb

#find mpirun command frim hpchub env
MPIRUN=`echo $HPCHUB_MPIRUN | awk '{print $1}'`

#define bind and ppn for mpi (Open MPI)
if [ "`$MPIRUN --help | grep 'Open MPI'`" != "" ]; then
	MPIRUN_BIND='--bind-to core'
	PPN='--npernode'
fi

#save base machinefile
mv machinefile machinefile_reserv

NODES=`cat machinefile_reserv | uniq`
NCPU=`cat machinefile_reserv | `
#----------------------
#Start NPB is  lu ft mg cg tests
#----------------------
NNODES=`cat machinefile_reserv | uniq | wc -l`
NODES_ARRAY=($(cat machinefile_reserv | uniq))

for i in `seq 1 $NNODES`; do
	echo i=$i
	for j in  `seq 1 $NCPU`; do
		echo j=$j
		for h in ${NODES_ARRAY[@]:0:$i}; do
			echo h=$h
			for k in `seq 1 $j`; do
				echo $h >> machinefile
			done
		done
		echo '-----------------------'
		echo machinefile:
		cat machinefile
		for test in "is lu ft mg cg ep dt sp"; do
			if [ -f ./bin/${test}.C.$((i*j)) ]; then
				echo Start IS
				echo nnodes=$i
				echo ppn=$j
				runstr="$MPIRUN -np $((j*i))  -machinefile machinefile $MPIRUN_BIND $PPN $j ./bin/${test}.C.$((i*j))"
				echo $runstr
				eval $runstr
				LogStep npb $test_$i $j
			fi
		done
	done
done

#revert macninefile
mv machinefile_reserv machinefile
