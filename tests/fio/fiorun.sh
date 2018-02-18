#!/bin/bash
op=$1
size=$2
(
 if flock -n 200; then
  ${HOME}/usr/bin/fio --name=global --rw=$op --size=$size --output=job.${HOSTNAME} --name=box.${HOSTNAME} 
 else 
  flock -x 200
 fi
) 200>lock.${HOSTNAME}

