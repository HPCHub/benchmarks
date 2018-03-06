#!/bin/bash
op=$1
size=$2
fio=$3
blocksize=$4
cd `dirname $fio`

(
 if flock -n 200; then
  if [ -f box.${HOSTNAME} ]; then
    rm -f box.${HOSTNAME}
  fi
  $fio --name=global --rw=$op --size=$size --output=job.${HOSTNAME} --name=box.${HOSTNAME} --blocksize=$blocksize
  rm -f box.${HOSTNAME}
  sleep 10
 else 
  flock -x 200
 fi
) 200>lock.${HOSTNAME}

