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

#find mpirun command frim hpchub env
MPIRUN=`echo $HPCHUB_MPIRUN | awk '{print $1}'`

#define bind and ppn for mpi (Open MPI)
if [ "`$MPIRUN --help | grep 'Open MPI'`" != "" ]; then
	MPIRUN_BIND=' --bind-to core --map-by socket'
	PPN='--npernode'
fi

#save base machinefile
mv machinefile machinefile_reserv

NODES=`cat machinefile_reserv | uniq`
TWO_NODES=`cat machinefile_reserv | uniq | head -n 2`

#----------------------
#Start OSU p2p tests
#----------------------

LogStep osu Start
if [ `echo $TWO_NODES | wc -w` -eq 2 ]; then
#	run osu_latency
	cat machinefile_reserv | uniq | head -n 2 > machinefile
	runstr="$MPIRUN -np 2  -machinefile machinefile $MPIRUN_BIND $PPN 1 ./mpi/pt2pt/osu_latency -x 10000 -i 100000 -m 131072"
	echo $runstr
	echo nnodes=2
	echo ppn=1
	eval $runstr
	rm machinefile
	LogStep osu latency
	
#	run osu_mbw_mr 
	for i in `seq 1 $NCPU`; do
			for h in $TWO_NODES; do
				for k in `seq 1 $i`; do
					echo $h >> machinefile
				done
			done
			runstr="$MPIRUN -np $((2*i))  -machinefile machinefile $MPIRUN_BIND $PPN $i ./mpi/pt2pt/osu_mbw_mr -V"
			echo $runstr
			echo nnodes=2
			echo ppn=$i
			eval $runstr
			LogStep osu mbw_mr $i
			rm machinefile
	done
else 
	echo WARNING: cannot run osu_latency and osu_mbw_mr tests: cannot find \>1 nodes
fi 

#----------------------
#Start OSU coll tests
#----------------------
NNODES=`cat machinefile_reserv | uniq | wc -l`
NODES_ARRAY=($(cat machinefile_reserv | uniq))

for i in `seq 1 $NNODES`; do
	echo i=$i
	for j in  `seq 1 $NCPU`; do
		if [ $((i*j)) -eq 1 ]; then
			continue
		fi
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
		echo '-----------------------'
		runstr="$MPIRUN -np $((j*i))  -machinefile machinefile $MPIRUN_BIND $PPN $j ./mpi/collective/osu_alltoall"
		echo $runstr
		echo nnodes=$i
		echo ppn=$j
		eval $runstr
		LogStep osu alltoall_$i $j
		runstr="$MPIRUN -np $((j*i))  -machinefile machinefile $MPIRUN_BIND $PPN $j ./mpi/collective/osu_barrier -i 400000"
		echo $runstr
		echo nnodes=$i
		echo ppn=$j
		eval $runstr
		LogStep osu barrier_$i $j
		runstr="$MPIRUN -np $((j*i))  -machinefile machinefile $MPIRUN_BIND $PPN $j ./mpi/collective/osu_allreduce"
		echo $runstr
		echo nnodes=$i
		echo ppn=$j
		eval $runstr
		LogStep osu  allreduce_$i $j
		rm machinefile
	done
done

#revert macninefile
mv machinefile_reserv machinefile
