#!/bin/bash
if [ -f ../platform.sh ]; then
  . ../platform.sh
fi

. include.sh

HPCHUB_TEST_STATE=run

if [ -f "${HPCHUB_PLATFORM}" ]; then
  . "${HPCHUB_PLATFORM}"
fi

if [ "$HPCHUB_ISNFS" = "1" ]; then
    PLATFORM_NAME="$(basename "$HPCHUB_PLATFORM" | sed -e "s/\..*//" )"
    if [ -f "../../local_platform_hooks/${PLATFORM_NAME}.run.sh" ]; then
        platform_hook_nfs_dir="$(. "../../local_platform_hooks/${PLATFORM_NAME}.run.sh"; echo "$platform_hook_nfs_dir")"
    else
        echo "Unable to find the file $(pwd)/../../local_platform_hooks/${PLATFORM_NAME}.run.sh, but HPCHUB_ISNFS=$HPCHUB_ISNFS"
        exit 1
    fi
    if [ "$(echo "$platform_hook_nfs_dir" | grep "^/" -c)" = "1" ]; then
        nfs_dir="$platform_hook_nfs_dir"
    else
        nfs_dir="$(pwd)/$platform_hook_nfs_dir"
    fi
fi

if [ "${HPCHUB_REPORT}" = "" ]; then
  report_to=../report.time.txt
else
  report_to="${HPCHUB_REPORT}"
fi

. ../include/logger.sh

cd "${fio_dir}"

if [ -f "${HPCHUB_MACHINEFILE}" ];then
  cp "${HPCHUB_MACHINEFILE}" ./machinefile
else
  if [ -f ../machinefile ]; then cp ../machinefile ./ ; fi
fi

LogStep fio-noargs Start 

function getbw { 
  value="$(cat job* | perl -e '$S=0;$N=0;while(<>){if(s/.*bw=(\d+.?\d*).*/$1/) { $S+=$_; $N++;} ; }; print $S/$N; ')"
  echo "getbw.value: $value"
  if [ "$value" = "" ]; then
    value="0.0";  
  fi; 
}

function getlat {
  
  value="$(cat job* | perl -e '$S=0;$N=0;while(<>){if(s/.* lat.*avg=(\d+\.?\d*),.*/$1/) { $S+=$_; $N++;} ; }; print $S/$N;')"
  
  echo "getlat.value: $value"
  if [ "$value" = "" ]; then
    value="0.0";  
  fi; 
}

if [ "$HPCHUB_PLATFORM" == 'azure' ]; then
	cp -r ../fio ~/nfs
	cd ~/nfs/fio
elif [ -n "$nfs_dir" ]; then
    cp -r ../../fio "$nfs_dir"
    cd "$nfs_dir/fio/$fio_dir"
fi

for size in 128m 512m; do
for blocksize in 4096 1024k; do 
for op in "randread" "randwrite" "read" "write" ; do
    if [ "$HPCHUB_ISLOCAL" = 1 -o -n "$nfs_dir" ]; then
        rm -f job*
    else
        for node in $NODES; do
            ssh "$node" "rm -f $(pwd)/job*"
        done
    fi 
  
    export NCPU=$((NNODES * 1)) 

    ${HPCHUB_MPIRUN} "$(pwd)/fiorun.sh" "$op" "$size" "$(pwd)/fio" "$blocksize"
    ${HPCHUB_MPIWAIT}

    if [ "$HPCHUB_ISLOCAL" != 1 -a -z "$nfs_dir" ]; then
        for node in $NODES; do
            scp "$node:$(pwd)/job*" ./
        done
    fi
        
    getbw

    LogStep fio-${size}-${op}-bs-${blocksize} BW $value

    getlat
  
    LogStep fio-${size}-${op}-bs-${blocksize} Latency.avg $value

    for i in job*; do
        mv "$i" "log-${size}-${op}-$i"
        echo "log-${size}-${op}-$i: "
        cat "log-${size}-${op}-$i"
    done
done
done
done
