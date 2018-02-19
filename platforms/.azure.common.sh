#!/bin/bash

HPCHUB_PLATFORM='azure'

OMP_NUM_THREADS=$(($NCPU/$NNODES))
NODES=`eval "echo hpchub-centos-h-{1..$NNODES}"`

FFTW_CONFIGURE_FLAGS=""
for feature in sse2 avx avx2; do
  if grep $feature /proc/cpuinfo > /dev/null; then
FFTW_CONFIGURE_FLAGS="${FFTW_CONFIGURE_FLAGS} --enable-$feature"
  fi
done

HPCHUB_PWD=`pwd`
HPCHUB_HAS_CPUSET=1

if [ "$HPCHUB_OPERATION" == "install_system" ]; then
  echo YUM:
  sudo yum -y install atlas cmake blas-devel gcc gcc-c++ gcc-gfortran
  for i in $NODES; do
    ssh -oStrictHostKeyChecking=no $i  sudo yum -y install atlas cmake blas-devel gcc gcc-c++ gcc-gfortran
  done
  echo Install MPICH 3.2
  wget http://www.mpich.org/static/downloads/3.2.1/mpich-3.2.1.tar.gz
  tar -xf mpich-3.2.1.tar.gz
  cd ./mpich-3.2.1
  ./configure --prefix=$HPCHUB_PWD/install
  make -j8
  make install
  echo Copying MPICH 3.2 to the nodes
  cd $HPCHUB_PWD
  for i in $NODES; do
	scp -oStrictHostKeyChecking=no -r ./install $i:$HPCHUB_PWD
  done
fi

export MPICC=$HOME/hpchub_benchmark/install/bin/mpicc
export MPICXX=$HOME/hpchub_benchmark/install/bin/mpicxx
export MPIFC=$HOME/hpchub_benchmark/install/bin/mpif90

if [ ! -x "$CC" ]; then
  export CC=$MPICC
fi
if [ ! -x "$CC" ]; then
  if [ "$HPCHUB_TEST_STATE" == "install" ]; then
    echo "Platform error: no C compiler installed!"
    exit 1
  fi
fi

if [ ! -x "$CXX" ]; then
  export CXX=$MPICXX
fi
if [ ! -x "$CXX" ]; then
  if [ "$HPCHUB_TEST_STATE" == "install" ]; then
    echo "Platform error: no CXX compiler installed!"
    exit 1
  fi
fi

if [ ! -x "$FC" ]; then
  export FC=$MPIFC
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

export FFTW_CONFIGURE_FLAGS
export HPCHUB_LINKER=$MPICC
export HPCHUB_LAPACK_DIR="/usr/lib"

source /opt/intel/impi/2017.2.174/bin64/mpivars.sh

if [ ! -f machinefile ]; then
	for h in $NODES; do
		echo $h >> machinefile
	done
fi

function hpchub_mpirun {
    HPCHUB_PPN=$((NCPU/NNODES))
    WD=`pwd`
	if [ -z $OMP_NUM_THREADS ] || [ $OMP_NUM_THREADS -eq 1 ]; then
		echo  mpirun -env I_MPI_FABRICS=shm:dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 -env I_MPI_DYNAMIC_CONNECTION=0 -env I_MPI_PIN_PROCESSOR_LIST=allcores:map=scatter --hostfile machinefile -n $NCPU -ppn $HPCHUB_PPN $@
		mpirun -env I_MPI_FABRICS=shm:dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 -env I_MPI_DYNAMIC_CONNECTION=0 -env I_MPI_PIN_PROCESSOR_LIST=allcores:map=scatter --hostfile machinefile -n $NCPU -ppn $HPCHUB_PPN $@
	else
		echo  mpirun -env I_MPI_FABRICS=shm:dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 -env I_MPI_DYNAMIC_CONNECTION=0 --hostfile machinefile -n $NCPU -ppn $HPCHUB_PPN $@
		mpirun -env I_MPI_FABRICS=shm:dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 -env I_MPI_DYNAMIC_CONNECTION=0 -env I_MPI_PIN_DOMAIN=omp --hostfile machinefile -n $NCPU -ppn $HPCHUB_PPN $@
	fi
}

function hpchub_mpirun_compile {
	HPCHUB_PPN=$((NCPU/NNODES))
    WD=`pwd`
	echo  mpirun -env I_MPI_FABRICS=shm:dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 -env I_MPI_DYNAMIC_CONNECTION=0 --hostfile machinefile -n $NCPU -ppn $HPCHUB_PPN $@
	mpirun -env I_MPI_FABRICS=shm:dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 -env I_MPI_DYNAMIC_CONNECTION=0 --hostfile machinefile -n $NCPU -ppn $HPCHUB_PPN $@
}




export HPCHUB_COMPILE_PREFIX=""



export HPCHUB_MPIRUN="hpchub_mpirun"

