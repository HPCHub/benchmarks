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

local_NCPU=$NPCU
local_NNODES=$NNODES
LogStep osu Start
if [ $NNODES -lt 2 ]; then
	echo WARNING: fail to run osu_latency and osu_mbw_mr tests: can not find 2 nodes
else
#	run osu_latency
	export NNODES=2
	export NCPU=$(($NNODES*1))
	runstr="hpchub_mpirun $PWD/mpi/pt2pt/osu_latency -x 10000 -i 100000 -m 131072 | tee -a  ${OSU_RESULTS}/osu_latency.2.1.out"
	echo $runstr | tee -a  ${OSU_RESULTS}/osu_latency.2.1.out
	eval $runstr
	export NCPU=$local_NCPU
	LogStep osu latency

#	run osu_mbw_mr 
	for i in `echo ${LOG_PPN}`; do
			export NNODES=2
			export NCPU=$(($NNODES*$i))
			runstr="hpchub_mpirun $PWD/mpi/pt2pt/osu_mbw_mr -V -m 2097152 | tee -a ${OSU_RESULTS}/osu_mbw_mr.2.$i.out"
			echo $runstr | tee -a  ${OSU_RESULTS}/osu_mbw_mr.2.$i.out
			eval $runstr
			LogStep osu mbw_mr_2_$i 1
	done
fi

#----------------------
#Start OSU coll tests
#----------------------

for i in `seq 1 $NNODES`; do
	for j in  `echo $LOG_PPN`; do
		if [ $((i*j)) -eq 1 ]; then
			continue
		fi
		export NNODES=$i
		export NCPU=$(($NNODES*$j))
		runstr="hpchub_mpirun  $PWD/mpi/collective/osu_alltoall | tee -a ${OSU_RESULTS}/osu_alltoall.$i.$j.out"
		echo $runstr | tee -a ${OSU_RESULTS}/osu_alltoall.$i.$j.out
		eval $runstr
		LogStep osu alltoall_$i $j
		runstr="hpchub_mpirun $PWD/mpi/collective/osu_barrier -i 400000 | tee -a ${OSU_RESULTS}/osu_barrier.$i.$j.out"
		echo $runstr | tee -a ${OSU_RESULTS}/osu_barrier.$i.$j.out
		eval $runstr
		LogStep osu barrier_$i $j
		runstr="hpchub_mpirun $PWD/mpi/collective/osu_allreduce | tee -a ${OSU_RESULTS}/osu_allreduce.$i.$j.out"
		echo $runstr | tee -a ${OSU_RESULTS}/osu_allreduce.$i.$j.out
		eval $runstr
		LogStep osu  allreduce_$i $j
	done
done

#revert macninefile
#mv machinefile_reserv ./machinefile
