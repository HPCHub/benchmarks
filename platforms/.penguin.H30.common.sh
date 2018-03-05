
#NNODES=4

#NCPU=48

export OMP_NUM_THREADS=1

HPCHUB_PPN=$((NCPU/NNODES))

if [ "$HPCHUB_PENGUIN_PHASE" = "" -a "${HPCHUB_TEST_STATE}" != "install" ]; then
#
# We are running externally.
# We have to prepare pbs file to run our selves and 
# submit it
#
L=`qstat | wc -l`
HPCHUB_PWD=`pwd`
rm _mpirun_penguin_hpchub.pbs
rm _mpirun_penguin_hpchub.stdout
rm _mpirun_penguin_hpchub.stderr
cat > _mpirun_penguin_hpchub.pbs <<EOF
#PBS -q H30
#PBS -l nodes=$NNODES:ppn=$HPCHUB_PPN
#PBS -l walltime=02:40:00
#PBS -S /bin/bash
#PBS -o $HPCHUB_PWD/_mpirun_penguin_hpchub.stdout
#PBS -e $HPCHUB_PWD/_mpirun_penguin_hpchub.stderr
cd $HPCHUB_PWD
export HPCHUB_PENGUIN_PHASE=internal
export HPCHUB_PLATFORM=${HPCHUB_PLATFORM} 
export HPCHUB_REPORT=${HPCHUB_REPORT}
export HPCHUB_RESDIR=${HPCHUB_RESDIR}
export NNODES=$NNODES
export NCPU=$NCPU
export HPCHUB_MACHINEFILE=\$PBS_NODEFILE

module load atlas/3.11.38/gcc.4.9.0
module load openmpi/2.0.0/gcc.4.9.0
module load cmake/3.3.1

./${HPCHUB_TEST_STATE}.sh

EOF
qsub _mpirun_penguin_hpchub.pbs

echo "penguin: job file ${HPCHUB_PWD}/_mpirun_penguin_hpchub.pbs submitted to pbs, waiting for it to disapear from qstat output"
while [ `qstat | wc -l` -gt "$L" ]; do
   echo -ne '.'
   sleep 10
done
echo "Stdout:"
cat $HPCHUB_PWD/_mpirun_penguin_hpchub.stdout
echo "Stderr:"
cat $HPCHUB_PWD/_mpirun_penguin_hpchub.stderr
exit 0
fi

FFTW_CONFIGURE_FLAGS=""
for feature in sse2 avx avx2; do
  if grep $feature /proc/cpuinfo > /dev/null; then
FFTW_CONFIGURE_FLAGS="${FFTW_CONFIGURE_FLAGS} --enable-$feature"
  fi
done

#module load blas/3.5.0/gcc.4.4.7
#module load lapack/3.7.0/gcc.4.4.7
module load openmpi/2.0.0/gcc.4.9.0
module load atlas/3.11.38/gcc.4.9.0
#module load fftw/3.3.4/gcc.4.4.7
module load cmake/3.3.1

export LAlib="/public/apps/lapack/3.7.0/gcc.4.4.7/lib64/liblapack.a /public/apps/lapack/3.7.0/gcc.4.4.7/lib64/libblas.a"


HPCHUB_HAS_CPUSET=1
WD=`pwd`
bwd=`basename $WD`

echo "current test, patform thinks : $bwd"
if [ "$bwd" != 'fio' ]; then
  echo "CC redefining: "
  export CC=`which mpicc`
  if [ ! -x "$CC" ]; then
    export CC=`which gcc`
  fi
  if [ ! -x "$CC" ]; then
    if [ "$HPCHUB_TEST_STATE" == "install" ]; then
      echo "Platform error: no C compiler installed!"
      exit 1
    fi
  else
    echo "Platform CC: $CC"
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
  PPN=$((NCPU/NNODES))
  mpirun -N $PPN -n $NCPU $@
}

function hpchub_mpirun_compile {
    L=`qstat | wc -l`
    WD=`pwd`
    cat > _mpirun_hpchub.pbs <<EOF
#PBS -q FREE
#PBS -l nodes=1
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
$@
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




#export HPCHUB_COMPILE_PREFIX="hpchub_mpirun_compile"
export HPCHUB_COMPILE_PREFIX=""



export HPCHUB_MPIRUN="hpchub_mpirun"
#export HPCHUB_MPIRUN="mpirun"
export MPICC=`which mpicc`
export MPICXX=`which mpicxx`
export MPIFC=`which mpif90`
export CC=$MPICC
