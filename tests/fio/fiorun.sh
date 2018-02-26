#!/bin/bash
op=$1
size=$2
fio=$3
(
 if flock -n 200; then
  $fio --name=global --rw=$op --size=$size --output=job.${HOSTNAME} --name=box.${HOSTNAME} 
  rm -f box.${HOSTNAME}
  sleep 10
 else 
  flock -x 200
 fi
) 200>lock.${HOSTNAME}

