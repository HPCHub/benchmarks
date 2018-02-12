
NNODES=4

NCPU=48

export OMP_NUM_THREADS=12

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
  
  sudo yum -y install atlas cmake blas-devel
  for i in $NODES; do
    ssh $i  sudo yum -y install atlas cmake blas-devel
  done
fi
export FFTW_CONFIGURE_FLAGS
export HPCHUB_LINKER=`which mpif77`
export HPCHUB_LAPACK_DIR="/usr/lib"

HPCHUB_PWD=`pwd`

function hpchub_mpirun {
    L=`qstat | wc -l`
    HPCHUB_PPN=$((NCPU/NNODES))
    WD=`pwd`
    cat > _mpirun_hpchub.pbs <<EOF
#PBS -q FREE
#PBS -l nodes=$NODES:ppn=$HPCHUB_PPN
#PBS -l walltime=00:15:00
#PBS -S /bin/bash
#PBS -o $HPCHUB_PWD/_mpirun_hpchub.stdout
#PBS -e $HPCHUB_PWD/_mpirun_hpchub.stderr
module load openmpi/1.5.5/gcc.4.4.6
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

function hpchub_mpirun_install {
    L=`qstat | wc -l`
    HPCHUB_PPN=$((NCPU/NNODES))
    WD=`pwd`
    cat > _mpirun_hpchub.pbs <<EOF
#PBS -q FREE
#PBS -l nodes=1:ppn=$HPCHUB_PPN
#PBS -l walltime=00:30:00
#PBS -S /bin/bash
#PBS -o $HPCHUB_PWD/_mpirun_hpchub.stdout
#PBS -e $HPCHUB_PWD/_mpirun_hpchub.stderr
module load openmpi/1.5.5/gcc.4.4.6
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

