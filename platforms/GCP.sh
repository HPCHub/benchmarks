#!/bin/bash

if [ "$HPCHUB_ISLOCAL" != "1" ]; then
    echo "Cluster mode is not supported"
    exit 1
    NODES="$(grep 'ibn00*' /etc/hosts | awk '{ print $2 }')"
    NNODES="$(echo "$NODES" | wc -w)"

    NCPU="$(for i in $NODES; do ssh $i grep "processor" /proc/cpuinfo ; done | wc -l)"

    MINCORES="999999"
    for node in $NODES; do
	    s="$(ssh "$node" lscpu | grep -oP "Socket\(s\):[ ]*\K[0-9]+")"
    	cps="$(ssh "$node" lscpu | grep -oP "Core\(s\) per socket:[ ]*\K[0-9]+")"
        cores="$((s * cps))"
    	if [ -z "$MINCORES" -o "$MINCORES" -gt "$cores" ]; then
	    	MINCORES="$cores"
    	fi
    done

    NCPU="$((MINCORES * NNODES))"
	HPCHUB_MPIRUN_OPTIONS=""
else
    NODES="$(hostname)"
    NNODES="1"
	    
    s="$(lscpu | grep -oP "Socket\(s\):[ ]*\K[0-9]+")"
    cps="$(lscpu | grep -oP "Core\(s\) per socket:[ ]*\K[0-9]+")"
    MINCORES="$((s * cps))"
    NCPU="$MINCORES"
	HPCHUB_MPIRUN_OPTIONS=""
fi

export MINCORES

#export OMP_NUM_THREADS=`ssh n001 cat /proc/cpuinfo | grep processor | wc -l`

FFTW_CONFIGURE_FLAGS=""
for feature in sse2 avx avx2; do
  if grep $feature /proc/cpuinfo > /dev/null; then
FFTW_CONFIGURE_FLAGS="${FFTW_CONFIGURE_FLAGS} --enable-$feature"
  fi
done

HPCHUB_HAS_CPUSET=1

export CC="$(which mpicc)"
if [ ! -x "$CC" ]; then
  export CC="$(which gcc)"
fi
if [ ! -x "$CC" ]; then
  if [ "$HPCHUB_TEST_STATE" == "install" ]; then
    echo "Platform error: no C compiler installed!"
    exit 1
  fi
fi

export CXX="$(which mpicxx)"
if [ ! -x "$CXX" ]; then
  export CXX="$(which g++)"
fi
if [ ! -x "$CXX" ]; then
  if [ "$HPCHUB_TEST_STATE" == "install" ]; then
    echo "Platform error: no CXX compiler installed!"
    exit 1
  fi
fi

export FC="$(which mpif90)"

export MPICC="$(which mpicc)"
export MPICXX="$(which mpicxx)"
export MPIF77="$(which mpif77)"
export MPIF90="$(which mpif90)"
export MPIFC="$(which mpif90)"

if [ ! -x "$FC" ]; then
  export FC="$(which mpif90)"
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

if [ "$HPCHUB_TEST_STATE" = "install" ]; then
  echo YUM:
  
  sudo yum -y install libaio libaio-devel 
  for i in $NODES; do
    ssh "$i"  sudo yum -y install libaio libaio-devel
  done
fi

export FFTW_CONFIGURE_FLAGS
export HPCHUB_LINKER="$(which mpif77)"
export HPCHUB_LAPACK_DIR="/usr/lib"

HPCHUB_PWD="$(pwd)"

function hpchub_mpirun {
	HPCHUB_PPN="$((NCPU/NNODES))"
	NODES_ARRAY=($NODES)
	rm machinefile
	if [ -z "$OMP_NUM_THREADS" ] || [ "$OMP_NUM_THREADS" -eq 1 ]; then
		for _h in  ${NODES_ARRAY[@]:0:$NNODES}; do
			echo "$_h slots=$HPCHUB_PPN" >> machinefile
		done
		echo cat machinefile
		cat machinefile
		if [ "$MINCORES" -ge "$HPCHUB_PPN" ]; then
			echo "mpirun $HPCHUB_MPIRUN_OPTIONS -np "$NCPU" -machinefile machinefile --map-by socket --bind-to core  "$@""
			mpirun $HPCHUB_MPIRUN_OPTIONS -np "$NCPU" -machinefile machinefile --map-by socket --bind-to core  "$@"
		else
			echo "mpirun $HPCHUB_MPIRUN_OPTIONS -np "$NCPU" -machinefile machinefile --map-by socket  "$@""
			mpirun $HPCHUB_MPIRUN_OPTIONS -np "$NCPU" -machinefile machinefile --map-by socket  "$@"
		fi
	else
		echo ""
#	    cpu_cores=`for i in $NODES; do ssh \$i cat /proc/cpuinfo | grep processor; done | wc -l`
#		if [ $(($cpu_cores/$NNODES)) -lt $(($HPCHUB_PPN*$OMP_NUM_THREADS)) ]; then
#			echo ERROR: not enough cores cpu cores=$cpu_cores ppn=$HPCHUB_PPN OMP_NUM_THREADS=$OMP_NUM_THREADS
#		fi
#		for _h in  ${NODES_ARRAY[@]:0:$NNODES}; do
#			echo $h slots=$(($HPCHUB_PPN*$OMP_NUM_THREADS)) >> machinefile
#		done
#		mpirun -np $NCPU -machinefile machinefile -n $NCPU --map-by socket:pe=$OMP_NUM_THREADS --bind-to core $@
	fi
}


if [ ! -f machinefile ]; then 
   for h in $NODES; do
    for i in $(seq 1 $((NCPU/NNODES))); do
      echo "$h" >> machinefile
    done
   done
fi

export HPCHUB_MPIRUN="hpchub_mpirun"
export HPCHUB_COMPILE_PREFIX=""
