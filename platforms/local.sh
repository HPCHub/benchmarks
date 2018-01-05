NCPU=`cat /proc/cpuinfo  | grep processor | wc -l`

export OMP_NUM_THREADS=$NCPU
