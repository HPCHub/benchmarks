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

OSU_RESULTS=../../../$HPCHUB_RESDIR
mkdir -p $OSU_RESULTS

#FIXME: not portable
#find mpirun command frim hpchub env
MPIRUN=`echo $HPCHUB_MPIRUN | awk '{print $1}'`

#FIXME:add Intel MPI, MPICH, ...
#define bind and ppn for mpi (Open MPI)
#if [ "`$MPIRUN --help | grep 'Open MPI'`" != "" ]; then
#	MPIRUN_BIND=' --bind-to core'
#	PPN='--npernode'
#fi

#save base machinefile
#mv machinefile machinefile_reserv


#FIXME: not portable
#generate round robin cpuset
#if [ "$HPCHUB_HAS_CPUSET" -eq "1" ]; then
#  i=0
#  j=$((NCPU/NNODES/2))
#  rr_cpuset=$i,$j
#  while [ $j -le $(((NCPU/NNODES)-2)) ]; do
#	let i=i+1
#	let j=j+1
#	rr_cpuset=${rr_cpuset},$i,$j
#  done
#  HPCHUB_CPUSET="--cpu-set $rr_cpuset"
#else
#  HPCHUB_CPUSET=""
#fi

#FIXME: not portable
#NODES=`cat machinefile_reserv | uniq`
#NNODES=`cat machinefile_reserv | uniq | wc -l`
#NODES_ARRAY=($(cat machinefile_reserv | uniq))

i=2
LOG_PPN='1'
while [ $i -le $((NCPU/NNODES)) ]; do
	LOG_PPN="$LOG_PPN $i"
	let i=i*2
done
let i=i/2
if [ $i -ne $((NCPU/NNODES)) ]; then
	LOG_PPN="$LOG_PPN $((NCPU/NNODES))"
fi
echo LOG_PPN=$LOG_PPN


#----------------------
#Start OSU p2p tests
#----------------------

LogStep osu Start
#if [ `echo ${NODES_ARRAY[@]:0:2} | wc -w` -eq 2 ]; then
#	run osu_latency
#	for h in ${NODES_ARRAY[@]:0:2}; do
#		echo $h slots=1 >> machinefile
#	done
	echo nnodes=2
	echo ppn=1
	resbv_NCPU=$NPCU
	NCPU=$(($NNODES*2))
	runstr="hpchub_mpirun ./mpi/pt2pt/osu_latency -x 10000 -i 100000 -m 131072 | tee -a  ${OSU_RESULTS}/osu_latency.2.1.out"
#	echo  machinefile: | tee ${OSU_RESULTS}/osu_latency.2.1.out
#	cat machinefile | tee -a  ${OSU_RESULTS}/osu_latency.2.1.out
	echo $runstr | tee -a  ${OSU_RESULTS}/osu_latency.2.1.out
	eval $runstr
#	rm machinefile
	LogStep osu latency

#	run osu_mbw_mr 
#	for i in `echo ${LOG_PPN}`; do
#			for h in  ${NODES_ARRAY[@]:0:2}; do
#				echo $h  slots=$i >> machinefile
#			done
#			echo nnodes=2
#			echo ppn=$i
#			runstr="$MPIRUN  -np $((2*$i)) -machinefile machinefile $MPIRUN_BIND ${HPCHUB_CPUSET} ./mpi/pt2pt/osu_mbw_mr -V | tee -a ${OSU_RESULTS}/osu_mbw_mr.2.$i.out"
#			echo  machinefile: | tee ${OSU_RESULTS}/osu_mbw_mr.2.$i.out
#			cat machinefile | tee -a  ${OSU_RESULTS}/osu_mbw_mr.2.$i.out
#			echo $runstr | tee -a  ${OSU_RESULTS}/osu_mbw_mr.2.$i.out
##			eval $runstr
#			LogStep osu mbw_mr_2_$i 1
#			rm machinefile
#	done
#else 
#	echo WARNING: fail to run osu_latency and osu_mbw_mr tests: can not find 2 nodes
#fi 

#----------------------
#Start OSU coll tests
#----------------------

#for i in `seq 1 $NNODES`; do
#	for j in  `echo $LOG_PPN`; do
#		if [ $((i*j)) -eq 1 ]; then
#			continue
#		fi
#		for h in ${NODES_ARRAY[@]:0:$i}; do
#			echo $h slots=$j >> machinefile
#		done
#		echo '-----------------------'
#		echo machinefile:
#		cat machinefile
#		echo '-----------------------'
#		echo nnodes=$i
#		echo ppn=$j
#		runstr="$MPIRUN -np $((j*i))  -machinefile machinefile $MPIRUN_BIND ${HPCHUB_CPUSET} ./mpi/collective/osu_alltoall | tee -a ${OSU_RESULTS}/osu_alltoall.$i.$j.out"
#		echo machinefile: | tee ${OSU_RESULTS}/osu_alltoall.$i.$j.out
#		cat machinefile | tee -a ${OSU_RESULTS}/osu_alltoall.$i.$j.out
#		echo $runstr | tee -a ${OSU_RESULTS}/osu_alltoall.$i.$j.out
#		eval $runstr
#		LogStep osu alltoall_$i $j
#		echo nnodes=$i
#		echo ppn=$j
#		runstr="$MPIRUN -np $((j*i))  -machinefile machinefile $MPIRUN_BIND ${HPCHUB_CPUSET} ./mpi/collective/osu_barrier -i 400000 | tee -a ${OSU_RESULTS}/osu_barrier.$i.$j.out"
#		echo machinefile: | tee ${OSU_RESULTS}/osu_barrier.$i.$j.out
#		cat machinefile | tee -a ${OSU_RESULTS}/osu_barrier.$i.$j.out
#		echo $runstr | tee -a ${OSU_RESULTS}/osu_barrier.$i.$j.out
#		eval $runstr
#		LogStep osu barrier_$i $j
#		echo nnodes=$i
#		echo ppn=$j
#		runstr="$MPIRUN -np $((j*i))  -machinefile machinefile $MPIRUN_BIND ${HPCHUB_CPUSET} ./mpi/collective/osu_allreduce | tee -a ${OSU_RESULTS}/osu_allreduce.$i.$j.out"
#		echo machinefile: | tee ${OSU_RESULTS}/osu_allreduce.$i.$j.out
#		cat machinefile | tee -a ${OSU_RESULTS}/osu_allreduce.$i.$j.out
#		echo $runstr | tee -a ${OSU_RESULTS}/osu_allreduce.$i.$j.out
#		eval $runstr
#		LogStep osu  allreduce_$i $j
#		rm machinefile
#	done
#done

#revert macninefile
#mv machinefile_reserv ./machinefile
