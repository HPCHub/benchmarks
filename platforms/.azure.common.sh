#!/bin/bash

NNODES=2

NCPU=$(($NNODES*8))

NODES=`eval "echo hpchub-centos{1..$NNODES}"`

export OMP_NUM_THREADS=8

FFTW_CONFIGURE_FLAGS=""
for feature in sse2 avx avx2; do
  if grep $feature /proc/cpuinfo > /dev/null; then
FFTW_CONFIGURE_FLAGS="${FFTW_CONFIGURE_FLAGS} --enable-$feature"
  fi
done

HPCHUB_PWD=`pwd`
HPCHUB_HAS_CPUSET=1

if [ ! -x "$CC" ]; then
  export CC=`which gcc`
fi
if [ ! -x "$CC" ]; then
  if [ "$HPCHUB_TEST_STATE" == "install" ]; then
    echo "Platform error: no C compiler installed!"
    exit 1
  fi
fi

if [ ! -x "$CXX" ]; then
  export CXX=`which g++`
fi
if [ ! -x "$CXX" ]; then
  if [ "$HPCHUB_TEST_STATE" == "install" ]; then
    echo "Platform error: no CXX compiler installed!"
    exit 1
  fi
fi

if [ ! -x "$FC" ]; then
  export FC=`which gfortran`
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
  sudo yum -y install atlas cmake blas-devel gcc gcc-c++ gcc-gfortran
  for i in $NODES; do
    ssh $i  sudo yum -y install atlas cmake blas-devel gcc gcc-c++ gcc-gfortran
  done
  wget http://www.mpich.org/static/downloads/3.2.1/mpich-3.2.1.tar.gz
  tar -xf mpich-3.2.1.tar.gz
  cd ./mpich-3.2.1
  ./configure --prefix=$HPCHUB_PWD/install
  make -j2
  make install
  cd $HPCHUB_PWD
  for i in $NODES; do
	scp -r ./install $i:$HPCHUB_PWD
  done
fi

export MPICC=${HPCHUB_PWD}/install/bin/mpicc
export MPICXX=${HPCHUB_PWD}/install/bin/mpicc
export MPIFC=${HPCHUB_PWD}/install/bin/mpif90

export FFTW_CONFIGURE_FLAGS
#export HPCHUB_LINKER=`which mpif77`
export HPCHUB_LAPACK_DIR="/usr/lib"

source /opt/intel/impi/2017.2.174/bin64/mpivars.sh
function hpchub_mpirun {
    L=`qstat | wc -l`
    HPCHUB_PPN=$((NCPU/NNODES))
    WD=`pwd`
    cat > _mpirun_hpchub.pbs <<EOF
#PBS -q FREE
#PBS -l nodes=$NNODES:ppn=$HPCHUB_PPN
#PBS -l walltime=00:15:00
#PBS -S /bin/bash
#PBS -o $HPCHUB_PWD/_mpirun_hpchub.stdout
#PBS -e $HPCHUB_PWD/_mpirun_hpchub.stderr
module load openmpi/2.0.1/gcc.4.9.0
module load fftw/3.3.4/gcc.4.9.0
module load cmake/3.3.1
cd $WD
mpirun $@
EOF
    qsub _mpirun_hpchub.pbs
    while [ `qstat | wc -l` -gt "$L" ]; do
      sleep 1
    done
    echo "hpchub_mpirun stdout:"
    cat $HPCHUB_PWD/_mpirun_hpchub.stdout
    echo "hpchub_mpirun stderr:"
    cat $HPCHUB_PWD/_mpirun_hpchub.stderr
}

function hpchub_mpirun_compile {
    L=`qstat | wc -l`
    HPCHUB_PPN=$((NCPU/NNODES))
    WD=`pwd`
    cat > _mpirun_hpchub.pbs <<EOF
#PBS -q FREE
#PBS -l nodes=1:ppn=1
#PBS -l walltime=00:05:00
#PBS -S /bin/bash
#PBS -o $HPCHUB_PWD/_mpirun_hpchub.stdout
#PBS -e $HPCHUB_PWD/_mpirun_hpchub.stderr
module load openmpi/2.0.1/gcc.4.9.0
module load fftw/3.3.4/gcc.4.9.0
module load cmake/3.3.1
export CC=\`which mpicc\`
export CXX=\`which g++\`
export FC=\`which mpif90\`
export HPCHUB_LINKER=\`which mpif77\`
FFTW_CONFIGURE_FLAGS=""
for feature in sse2 avx avx2; do
  if grep \$feature /proc/cpuinfo > /dev/null; then
FFTW_CONFIGURE_FLAGS="\${FFTW_CONFIGURE_FLAGS} --enable-\$feature"
  fi
done
export FFTW_CONFIGURE_FLAGS

cd $WD
mpirun $@
EOF
    qsub _mpirun_hpchub.pbs
    while [ `qstat | wc -l` -gt "$L" ]; do
      sleep 1
    done
    echo "hpchub_mpirun stdout:"
    cat $HPCHUB_PWD/_mpirun_hpchub.stdout
    echo "hpchub_mpirun stderr:"
    cat $HPCHUB_PWD/_mpirun_hpchub.stderr
}




export HPCHUB_COMPILE_PREFIX="hpchub_mpirun_compile"



export HPCHUB_MPIRUN="hpchub_mpirun"

