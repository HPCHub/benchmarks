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

#----------------------
#Start NPB is  lu ft mg cg tests
#----------------------

NNODES=`cat machinefile_reserv | uniq | wc -l`
NODES_ARRAY=($(cat machinefile_reserv | uniq))

maxiter=3

for i in `seq 1 $NNODES`; do
	for j in  `seq 1 $NCPU`; do
		for h in ${NODES_ARRAY[@]:0:$i}; do
			for k in `seq 1 $j`; do
				echo $h >> machinefile
			done
		done
		echo '-----------------------'
		echo machinefile:
		cat machinefile
		echo '-----------------------'
		for npb_test in "is" "lu" "ft" "mg" "cg" "ep" "dt" "sp"; do
			prg_nprocs=$((i*j))
			if [ $prg_nprocs -ge 256 ]; then
				maxiter=10
			elif [ $prg_nprocs -ge 32 ]; then
				maxiter=5
			else
				maxiter=3
			fi
			if [ -f ./bin/${npb_test}.C.$((i*j)) ]; then
				iter=1
				while [ $iter -le $maxiter ]; do
					echo nnodes=$i
					echo ppn=$j
					runstr="$MPIRUN -np $((j*i))  -machinefile machinefile ${MPIRUN_BIND} ${PPN} ${j} ./bin/${npb_test}.C.$((i*j)) | tee -a ${NPB_RESULTS}/${npb_test}.C.${i}.${j}.${iter}.out"
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
