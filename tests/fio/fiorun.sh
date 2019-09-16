#!/bin/bash
op="$1"
size="$2"
fio="$3"
blocksize="$4"
ppn="$5"

safe_mem="$((1024**3))" ## 1GB
bsize="512"

cd "$(dirname $fio)"
echo "FioRun. pwd: $(pwd); op: $op; size: $size; fio exec: $fio; blocksize: $blocksize; numjobs: $ppn"

avail_mem="$(df --output="avail" $(pwd) -B "$bsize" | head -2 | tail -1)"
avail_mem="$((avail_mem * bsize - safe_mem))"

req_mem="$(echo $size | tr "[:upper:]" "[:lower:]")"
val="$(echo "$req_mem" | grep -oP "\K[0-9]+")"
ext="$(echo "$req_mem" | grep -oP "\K[^0-9./]+" | tr "[:upper:]" "[:lower:]" | head -1)"

if [ "$ext" = "k" ]; then
	val=$((val * 1024 * ppn))
elif [ "$ext" = "m" ]; then
	val=$((val * 1024 * 1024 * ppn))
elif [ "$ext" = "g" ]; then
	val=$((val * 1024 * 1024 * 1024 * ppn))
fi

if [ "$val" -gt "$avail_mem" ]; then
	echo "Not enough memory. Required: $val; Available: $avail_mem"
	exit 2;
fi

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

if [ "$?" != "0" ]; then
	exit 1
else
	exit 0
fi

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

