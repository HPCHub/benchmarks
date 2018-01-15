NNODES=`cat /etc/hosts |  grep 'n.*\.vcluster' | wc -l`

NODES=`cat /etc/hosts | grep 'n.*\.vcluster' | awk '{print $2;};'`

NCPU=`for i in $NODES; do ssh \$i cat /proc/cpuinfo | grep processor; done | wc -l`

export OMP_NUM_THREADS=`ssh n001 cat /proc/cpuinfo | grep processor | wc -l`

FFTW_CONFIGURE_FLAGS=""
for feature in sse2 avx avx2; do
  if grep $feature /proc/cpuinfo > /dev/null; then
FFTW_CONFIGURE_FLAGS="${FFTW_CONFIGURE_FLAGS} --enable-$feature"
  fi
done

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

if [ "$HPCHUB_TEST_STATE" == "install" ]; then
  echo "Platform: using $CC as compiler"
fi

if [ "$HPCHUB_OPERATION" == "install_system" ]; then
  echo YUM:
  sudo yum -y install atlas cmake
fi
export FFTW_CONFIGURE_FLAGS
export HPCHUB_LINKER=`which mpif77`
export HPCHUB_LAPACK_DIR="/usr/lib"

HPCHUB_PWD=`pwd`
export HPCHUB_MPIRUN="mpirun -np $NCPU "

if [ ! -f machinefile ]; then 
    for i in `seq 1 $NCPU`; do
      echo localhost >> machinefile
    done
fi
