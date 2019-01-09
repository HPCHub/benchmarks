
NNODES=4
AVAIL_NNODES=`cat /opt/hpc/hostlist.rdma | wc -l`
if [ $AVAIL_NNODES -lt $NNODES ]; then
  echo "Platform error: not enough evailable nodes in  /opt/hpc/hostlist.rdma"
  exit 1
fi

NODES=`cat /opt/hpc/hostlist.rdma | tail -n $NNODES | awk '{print $1;};'`

NCPU=`for i in $NODES; do ssh \$i cat /proc/cpuinfo | grep processor; done | wc -l`

echo NNODE=$NODES
echo NCPU=$NCPU

#export OMP_NUM_THREADS=`ssh n001 cat /proc/cpuinfo | grep processor | wc -l`

FFTW_CONFIGURE_FLAGS=""
for feature in sse2 avx avx2; do
  if grep $feature /proc/cpuinfo > /dev/null; then
FFTW_CONFIGURE_FLAGS="${FFTW_CONFIGURE_FLAGS} --enable-$feature"
  fi
done

HPCHUB_HAS_CPUSET=1

export CC=`which mpicc`
if [ ! -x "$CC" ]; then
  export CC=`which gcc`
fi
if [ ! -x "$CC" ]; then
  if [ "$HPCHUB_TEST_STATE" == "install" ]; then
    echo "Platform error: no C compiler installed!"
    exit 1
  fi
fi

export CXX=`which mpicxx`
if [ ! -x "$CXX" ]; then
  export CXX=`which g++`
fi
if [ ! -x "$CXX" ]; then
  if [ "$HPCHUB_TEST_STATE" == "install" ]; then
    echo "Platform error: no CXX compiler installed!"
    exit 1
  fi
fi

export FC=`which mpif90`

export MPICC=`which mpicc`
export MPICXX=`which mpicxx`
export MPIF77=`which mpif77`
export MPIF90=`which mpif90`
export MPIFC=`which mpif90`

if [ ! -x "$FC" ]; then
  export FC=`which mpif90`
fi
if [ ! -x "$FC" ]; then
  if [ "$HPCHUB_TEST_STATE" == "install" ]; then
    echo "Platform error: no FC compiler installed!"
    exit 1
  fi
fi

if [ "$HPCHUB_TEST_STATE" == "install" ]; then
  echo "Platform: using $CC as compiler"
fi

if [ "$HPCHUB_OPERATION" == "install_system" ]; then
  echo YUM:
  
  sudo yum -y install atlas cmake blas-devel  gcc-c++ numpy
  for i in $NODES; do
    ssh $i  sudo yum -y install atlas cmake blas-devel gcc-c++ numpy
  done
fi
export FFTW_CONFIGURE_FLAGS
export HPCHUB_LINKER=`which mpif77`
export HPCHUB_LAPACK_DIR="/usr/lib"

HPCHUB_PWD=`pwd`

function hpchub_mpirun {
	HPCHUB_PPN=$(($NCPU/$NNODES))
	NODES_ARRAY=($NODES)
	rm machinefile
	if [ -z $OMP_NUM_THREADS ] || [ $OMP_NUM_THREADS -eq 1 ]; then
		for _h in  ${NODES_ARRAY[@]:0:$NNODES}; do
			echo $_h slots=$HPCHUB_PPN >> machinefile
		done
		echo cat machinefile
		cat machinefile
		mpirun -np $NCPU -machinefile machinefile --map-by socket --bind-to core  $@
	else
		cpu_cores=`for i in $NODES; do ssh \$i cat /proc/cpuinfo | grep processor; done | wc -l`
		if [ $(($cpu_cores/$NNODES)) -lt $(($HPCHUB_PPN*$OMP_NUM_THREADS)) ]; then
			echo ERROR: not enough cores cpu cores=$cpu_cores ppn=$HPCHUB_PPN OMP_NUM_THREADS=$OMP_NUM_THREADS
		fi
		for _h in  ${NODES_ARRAY[@]:0:$NNODES}; do
			echo $h slots=$(($HPCHUB_PPN*$OMP_NUM_THREADS)) >> machinefile
		done
		mpirun -x UCB_IB_TRAFFIC_CLASS=104 -x UCX_IB_GID_INDEX=3 -x HCOLL_ENABLE_MCAST_ALL=0 --cpu-set 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35 -np $NCPU -machinefile machinefile --map-by socket:pe=$OMP_NUM_THREADS --bind-to core $@
	fi
}


if [ ! -f machinefile ]; then 
   for h in $NODES; do
    for i in `seq 1 $(($NCPU/$NNODES))`; do
      echo $h >> machinefile
    done
   done
fi

export HPCHUB_MPIRUN="hpchub_mpirun"
export HPCHUB_COMPILE_PREFIX=""
