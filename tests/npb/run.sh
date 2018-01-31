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

NPB_RESULTS=../../../../$HPCHUB_RESDIR

mkdir -p $NPB_RESULTS


#find mpirun command frim hpchub env
MPIRUN=`echo $HPCHUB_MPIRUN | awk '{print $1}'`

#define bind and ppn for mpi (Open MPI)
if [ "`$MPIRUN --help | grep 'Open MPI'`" != "" ]; then
	MPIRUN_BIND='--bind-to core'
	PPN='--npernode'
fi

#save base machinefile
mv machinefile machinefile_reserv

#Is it good idea?
NODES=`cat machinefile_reserv | uniq`

#generate round robin cpuset
i=0
j=$((NCPU/NNODES/2))
rr_cpuset=$i,$j
let i=i+1
let j=j+1

while [ $j -le $(((NCPU/NNODES)-2)) ]; do
	rr_cpuset=${rr_cpuset},$i,$j
	let i=i+1
	let j=j+1
done

#----------------------
#Start NPB is  lu ft mg cg tests
#----------------------

NNODES=`cat machinefile_reserv | uniq | wc -l`
NODES_ARRAY=($(cat machinefile_reserv | uniq))


for i in `seq 1 $NNODES`; do
	for j in  `seq 1 $((NCPU/NNODES))`; do
		for h in ${NODES_ARRAY[@]:0:$i}; do
			echo $h slots=$j >> machinefile
		done
		for npb_test in "is" "lu" "ft" "mg" "cg" "ep" "bt" "sp"; do
			prg_nprocs=$((i*j))
			if [ $prg_nprocs -ge 256 ]; then
				maxiter=7
			elif [ $prg_nprocs -ge 16 ]; then
				maxiter=3
			elif [ $prg_nprocs -ge 4 ]; then
				maxiter=2
			else
				maxiter=1
			fi
			if [ -f ./bin/${npb_test}.C.$((i*j)) ]; then
				echo '-----------------------'
				echo machinefile:
				cat machinefile
				echo '-----------------------'
				iter=1
				while [ $iter -le $maxiter ]; do
					echo nnodes=$i
					echo ppn=$j
					runstr="$MPIRUN -np $((j*i))  -machinefile machinefile ${MPIRUN_BIND} --cpu-set $rr_cpuset ./bin/${npb_test}.C.$((i*j)) | tee -a ${NPB_RESULTS}/${npb_test}.C.${i}.${j}.${iter}.out"
					echo  machinefile: | tee $NPB_RESULTS/${npb_test}.C.${i}.$j.${iter}.out
					cat machinefile | tee -a $NPB_RESULTS/${npb_test}.C.${i}.$j.${iter}.out
					echo ${runstr} | tee -a $NPB_RESULTS/${npb_test}.C.${i}.$j.${iter}.out
					eval ${runstr}
					LogStep npb ${test}_${i}_${j} ${iter}
					let iter=iter+1
				done
			fi
		done
		rm machinefile
	done
done

#revert macninefile
mv machinefile_reserv machinefile
