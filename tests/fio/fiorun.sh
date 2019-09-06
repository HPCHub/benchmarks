#!/bin/bash
op="$1"
size="$2"
fio="$3"
blocksize="$4"
ppn="$5"
cd "$(dirname $fio)"
echo "FioRun. pwd: $(pwd); op: $op; size: $size; fio exec: $fio; blocksize: $blocksize; numjobs: $ppn"
$fio --rw=$op \
     --direct=1 \
     --ioengine=libaio \
     --runtime=120 \
     --group_reporting \
     --iodepth=1 \
     --size=$size \
     --numjobs=$ppn \
     --output=job.${HOSTNAME} \
     --name=box.${HOSTNAME} \
     --blocksize=$blocksize

exit "$?"

#(
# if flock -n 200; then
#  if [ -f box.${HOSTNAME} ]; then
#    rm -f box.${HOSTNAME}
#  fi
#  $fio --rw=$op --direct=1 --ioengine=libaio --runtime=120 --group_reporting --iodepth=1 --size=$size --output=job.${HOSTNAME} --name=box.${HOSTNAME} --blocksize=$blocksize
#  rm -f box.${HOSTNAME}
#  sleep 10
# else 
#  flock -x 200
# fi
#) 200>lock.${HOSTNAME}

