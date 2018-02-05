NCPU=`cat /proc/cpuinfo  | grep processor | wc -l`

export OMP_NUM_THREADS=$NCPU

FFTW_CONFIGURE_FLAGS=""
for feature in sse2 avx avx2; do
  if grep $feature /proc/cpuinfo > /dev/null; then
FFTW_CONFIGURE_FLAGS="${FFTW_CONFIGURE_FLAGS} --enable-$feature"
  fi
done

export CC=`which mpicc.mpich`
if [ ! -x "$CC" ]; then
  export CC=`which gcc`
fi
if [ ! -x "$CC" ]; then
  if [ "$HPCHUB_TEST_STATE" == "install" ]; then
    echo "Platform error: no C compiler installed!"
    exit 1
  fi
fi

if [ "$HPCHUB_OPERATION" == "install_system" ]; then
  sudo apt-get install build-essential gfortran mpich libblas-dev liblapack-dev cmake bc
fi

if [ "$HPCHUB_TEST_STATE" == "install" ]; then
  echo "Platform: using $CC as compiler"
fi

export FFTW_CONFIGURE_FLAGS
export HPCHUB_LINKER=`which mpif77.mpich`
export HPCHUB_LAPACK_DIR="/usr/lib"

export MPICC=`which mpicc`
export MPIF77=`which mpif77`
export MPIF90=`which mpif90`

HPCHUB_PWD=`pwd`
export HPCHUB_MPIRUN="mpirun.mpich -np $NCPU -machinefile machinefile "

if [ ! "$HPCHUB_OPTIMAL_OMP" = "" ]; then
  if [ "$OMP_NUM_THREADS" -gt $HPCHUB_OPTIMAL_OMP ]; then
     export OMP_NUM_THREADS=$HPCHUB_OPTIMAL_OMP
     NCPU=$((NCPU/OMP_NUM_THREADS))
     export HPCHUB_MPIRUN_OMP="mpirun.mpich -np $NCPU -machinefile machinefile "
  else
     export HPCHUB_MPIRUN_OMP="mpirun.mpich -np $NCPU -machinefile machinefile " 
  fi
fi
if [ ! -f machinefile ]; then 
    for i in `seq 1 $NCPU`; do
      echo localhost >> machinefile
    done
fi

if [ "$HPCHUB_BUILTIN_MPI" = "" ]; then
  export HPCHUB_MPIRUN_OMP=""
fi
