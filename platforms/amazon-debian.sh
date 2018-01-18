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
  sudo apt-get install build-essential gfortran mpich blas lapack cmake
fi

if [ "$HPCHUB_TEST_STATE" == "install" ]; then
  echo "Platform: using $CC as compiler"
fi

export FFTW_CONFIGURE_FLAGS
export HPCHUB_LINKER=`which mpif77.mpich`
export HPCHUB_LAPACK_DIR="/usr/lib"

HPCHUB_PWD=`pwd`
export HPCHUB_MPIRUN="mpirun.mpich -np $NCPU -machinefile machinefile "

if [ ! -f machinefile ]; then 
    for i in `seq 1 $NCPU`; do
      echo localhost >> machinefile
    done
fi
