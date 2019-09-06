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
    local N="0"
    local S="0"
    local val=""
    local strval=""
    local ext=""
    for i in job*; do
        if [ "$i" = "job*" ]; then
            break
        fi

        strval=$(grep -oP "bw=\K[0-9]+.?[0-9][^ ]*" "$i")
        val="$(echo "$strval" | grep -oP "\K[0-9]+.?[0-9]")"
        ext="$(echo "$strval" | grep -oP "\K[^0-9./]+" | tr "[:upper:]" "[:lower:]" | head -1)"

        if [ "$ext" = "k" -o "$ext" = "kb" -o "$ext" = "kib" ]; then
            val="$(python -c "print($val * 1024)")"
        elif [ "$ext" = "ki" ]; then
            val="$(python -c "print($val * 1000)")"
        elif [ "$ext" = "mib" -o "$ext" = "m" ]; then
            val="$(python -c "print($val * 1024**2)")"
        elif [ "$ext" = "mb" -o "$ext" = "mi" ]; then
            val="$(python -c "print($val * 1000**2)")"
        elif [ "$ext" = "tib" -o "$ext" = "t" ]; then
            val="$(python -c "print($val * 1024**3)")"
        elif [ "$ext" = "tb" -o "$ext" = "ti" ]; then
            val="$(python -c "print($val * 1000*3)")"
        fi    

        N="$((N+1))"
        S="$(python -c "print($S + $val)")"
    done

    if [ "$N" != "0" ]; then
            
        S="$(python -c "print(1. * $S / $N)")"
        S_ceil="$(echo "$S" |  grep -oE "[0-9]+" | head -1)"

        if [ "$S_ceil" -ge "$((1024 * 1024 * 1024))" ]; then
            ext="TiB"
            val="$(python -c "print \"%.3f\" % ($S/1024.**3)")"
        elif [ "$S_ceil" -ge "$((1024 * 1024))" ]; then
            ext="MiB"
            val="$(python -c "print \"%.3f\" % ($S/1024.**2)")"
        elif [ "$S_ceil" -ge "1024" ]; then
            ext="KiB"
            val="$(python -c "print \"%.3f\" % ($S/1024.)")"
        else
            ext="B"
        fi

        value="${val}${ext}/s"
        echo "getbw.value: ${value}"
    else 
        echo "getbw.value: "
        value="0.0";
    fi 
#  value="$(cat job* | perl -e '$S=0;$N=0;while(<>){if(s/.*bw=(\d+.?\d*).*/$1/) { $S+=$_; $N++;} ; }; print $S/$N; ')"
}

function getlat {
  
  value="$(cat job* | perl -e '$S=0;$N=0;while(<>){if(s/.* lat.*avg=(\d+\.?\d*),.*/$1/) { $S+=$_; $N++;} ; }; print $S/$N;')"
  
  echo "getlat.value: $value"
  if [ "$value" = "" ]; then
    value="0.0";  
  fi; 
}

function getiops {
  value="$(cat job* | perl -e '$S=0;$N=0;while(<>){if(s/.*iops=(\d+\.?\d*),.*/$1/) { $S+=$_; $N++;} ; }; print $S/$N;')"
  echo "getiops.value: $value"
  if [ "$value" = "" ]; then
    value="0.0";  
  fi
} 


if [ "$HPCHUB_PLATFORM" == 'azure' ]; then
	cp -r ../fio ~/nfs
	cd ~/nfs/fio
elif [ -n "$nfs_dir" ]; then
    cp -r ../../fio "$nfs_dir"
    cd "$nfs_dir/fio/$fio_dir"
fi

#$1 -- op
#$2 -- blocksize
#$3 -- jobs
#$4 -- size
function fio_wrapper
{
    local op="$1"
    local blocksize="$2"
    local ppn="$3"
    local size="$4"

    if [ "$HPCHUB_ISLOCAL" = 1 -o -n "$nfs_dir" ]; then
        rm -f job*
    else
        for node in $NODES; do
            ssh "$node" "rm -f $(pwd)/job*"
        done
    fi 
  
    export NCPU="$((NNODES * 1))" 

    ${HPCHUB_MPIRUN} "$(pwd)/fiorun.sh" "$op" "$size" "$(pwd)/fio" "$blocksize" "$ppn"
    [ "$?" != "0" ] && exit 1
    ${HPCHUB_MPIWAIT}

    if [ "$HPCHUB_ISLOCAL" != 1 -a -z "$nfs_dir" ]; then
        for node in $NODES; do
            scp "$node:$(pwd)/job*" ./
        done
    fi
        
    getbw

    LogStep "fio-${size}-${op}-bs-${blocksize}-ppn-${ppn}" BW "$value"

    getlat
  
    LogStep "fio-${size}-${op}-bs-${blocksize}-ppn-${ppn}" Latency.avg "$value"

    getiops
  
    LogStep "fio-${size}-${op}-bs-${blocksize}-ppn-${ppn}" IOPS "$value"

    for i in job*; do
        fname="log-${size}-${op}-${blocksize}-${ppn}-$i"
        mv "$i" "$fname"
        echo "$fname: "
        cat "$fname"
    done
}

#$1 - val
function ceil_log
{
    local i="2"
    while [ "$((i*i))" -lt "$1" ]; do
        i="$((i*2))"
    done
    echo "$((i*i))"
}

i="2"
LOG_PPN="1"
while [ "$i" -le "$((NCPU/NNODES))" ]; do
    LOG_PPN="$LOG_PPN $i"
    let i=i*2
done
let i=i/2
if [ "$i" -ne "$((NCPU/NNODES))" ]; then
    LOG_PPN="$LOG_PPN $((NCPU/NNODES))"
fi
    

for op in "randread" "randwrite" "read" "write" ; do
    for bs in  "512" "4096" "1024k" "1M" "16m" "128m"  "4095m" ; do
        for ppn in $LOG_PPN; do
            ceil_ppn="$(ceil_log "$ppn")"
            size=""
	        if [ "$bs" = 512 -o "$bs" = 4096 -o "$bs" = 1024k ]; then
		        size="$((256/ppn))M"
	        elif [ "$bs" = "1M" -o "$bs" = "16m" -o "$bs" = "128m" ]; then
		        size="$((16*1024/ceil_ppn))M"
	        elif [ "$bs" = "4095m" ]; then
    		    size="$((256 * 1024/ceil_ppn))M"
            fi
            if [ -n "$size" ]; then            
                fio_wrapper "$op" "$bs" "$ppn" "$size"
            fi
        done
    done
done
