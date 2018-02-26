## NNODES=$RESCALE_NNODES

NODES=`cat $HOME/machinefile`
NNODES=`cat $HOME/machinefile | sort -u | wc -l`

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

### TBD - double check on next run!
export MPICC=`which mpicc`
export MPIF77=`which mpif77`
export MPIF90=`which mpif90`
export MPIFC=`which mpif90`

HPCHUB_PWD=`pwd`

function hpchub_mpirun {
  PPN=$((NCPU/NNODES))
  mpirun -np $NCPU -ppn $PPN $@
}
export HPCHUB_MPIRUN="hpchub_mpirun"


if [ ! -f machinefile ]; then 
   for h in $NODES; do
    for i in `seq 1 $NCPU`; do
      echo $h >> machinefile
    done
   done
fi
