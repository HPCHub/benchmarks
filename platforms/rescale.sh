NNODES=$RESCALE_NNODES

NODES=`cat $HOME/machinefile`

NCPU=`for i in $NODES; do ssh \$i cat /proc/cpuinfo | grep processor; done | wc -l`

export OMP_NUM_THREADS=6

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
  
  sudo yum -y install atlas cmake blas-devel
  for i in $NODES; do
    ssh $i  sudo yum -y install atlas cmake blas-devel
  done
fi
export FFTW_CONFIGURE_FLAGS
export HPCHUB_LINKER=`which mpif77`
export HPCHUB_LAPACK_DIR="/usr/lib"
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/program/mpi/platformmpi/9.1.4/lib/linux_amd64
export MPI_F77=gfortran

HPCHUB_PWD=`pwd`
export HPCHUB_MPIRUN="mpirun -np $NCPU "


if [ ! -f machinefile ]; then 
   for h in $NODES; do
    for i in `seq 1 $NCPU`; do
      echo $h >> machinefile
    done
   done
fi
