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

echo npb NCPU=$NCPU 
echo npb NNODES=$NNODES

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

local_NCPU=$NCPU 
local_NNODES=$NNODES
local_OMP_NUM_THREADS=$OMP_NUM_THREADS
for i in `seq 1 $local_NNODES`; do
	for j in  `seq 1 $((local_NCPU/local_NNODES))`; do
		for npb_test in "is" "lu" "ft" "mg" "cg" "ep" "bt" "sp"; do
			prg_nprocs=$(($i*$j))
			export NNODES=$i
			export NCPU=$(($i*$j))
			if [ $prg_nprocs -ge 256 ]; then
				maxiter=7
			elif [ $prg_nprocs -ge 16 ]; then
				maxiter=3
			elif [ $prg_nprocs -ge 4 ]; then
				maxiter=2
			else
				maxiter=1
			fi
			if [ -f ./bin/${npb_test}.C.$(($i*$j)) ]; then
				iter=1
				while [ $iter -le $maxiter ]; do
					runstr="$HPCHUB_MPIRUN $PWD/bin/${npb_test}.C.$((i*j)) | tee -a ${NPB_RESULTS}/${npb_test}.C.${i}.${j}.${iter}.out"
					echo ${runstr} | tee -a $NPB_RESULTS/${npb_test}.C.${i}.$j.${iter}.out
					eval ${runstr}
					LogStep npb ${test}_${i}_${j} ${iter}
					let iter=iter+1
				done
			fi
		done
	done
done
export OMP_NUM_THREADS=$local_OMP_NUM_THREADS
export NCPU=$local_NCPU 
export NNODES=$local_NNODES 

