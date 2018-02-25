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
local_PPN=$((local_NCPU/local_NNODES))
# Run no more than two tests of each kind
declare -A tests_done
for i in `seq $local_NNODES -1 1`; do
	for j in  `seq $local_PPN -1 1`; do
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
                        maxiter=1
			if [ -f ./bin/${npb_test}.C.$(($i*$j)) ]; then
                                if [ "${tests_done[${npb_test}_$i]}" = "" ]; then
                                     tests_done[${npb_test}_$i]=1
                                else
                                     tests_done[${npb_test}_$i]=$((tests_done[${npb_test}_$i]+1))
                                fi
                                if [ "${tests_done[${npb_test}_$i]}" -le 2 ]; then
  					iter=1
					while [ $iter -le $maxiter ]; do
                                	        outfile=${NPB_RESULTS}/${npb_test}.C.${i}.${j}.${iter}.out
						runstr="$HPCHUB_MPIRUN $PWD/bin/${npb_test}.C.$((i*j)) | tee -a ${outfile}"
						echo ${runstr} | tee -a $outfile
						eval ${runstr}
                	                        Vtotal=`grep "Mop/s total" $outfile  | awk '{print $4; };'`
                        	                Vperprocess=`grep "Mop/s/process" $outfile  | awk '{print $3; };'`
						LogStep npb ${npb_test}_${i}_${j} ${iter}
						LogStep npb ${npb_test}_${i}_${j}_total $Vtotal
						LogStep npb ${npb_test}_${i}_${j}_perprocess $Vperprocess
						let iter=iter+1
                	                        echo "RunStr: $runstr"
					done
				fi
			fi
		done
	done
done
export OMP_NUM_THREADS=$local_OMP_NUM_THREADS
export NCPU=$local_NCPU 
export NNODES=$local_NNODES 

