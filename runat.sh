#!/bin/bash

if [ "$1" = "" -o ! -f platforms/${2}.sh -o "$3" = "" ]; then
  echo "Usage:"
  echo "  runat.sh [user@]HOST PLATFORM OPERATION"
  echo "where"
  echo "  HOST - some HOST, that current user can log in into using 'ssh HOST' command"
  echo "         (hint: use ~/.ssh/config to set it up accordingly)"
  echo "  PLATFORM - platform, expected to exist on host. One of:"
  ls platforms/ | tr '.' ' '| awk '{print $1;};'
  echo "  OPERATION - one of: install run clean"
  echo "              (hint: after install one can call run multiple times)"
  exit 1
fi

if [ ! -d "runs" ]; then 
  mkdir runs
fi

remhost=$1
platform=$2
operation=$3
remwd=`ssh $remhost pwd`

if [ ! "$?" = "0" -o "$remwd" = "" ]; then
  echo "Problems connecting to host $remhost"
  exit 2
fi

if [ "$operation" = "install" ]; then
  git archive --format tar.gz master | ssh $remhost "cat > hpchub_benchmark.tar.gz"
  ssh $remhost "mkdir hpchub_benchmark" 
  ssh $remhost "cd hpchub_benchmark; tar -xvzf ../hpchub_benchmark.tar.gz" || exit 4
  for i in tests/*; do
    if [ -d "$i" -a ! "$i" = "tests/include" -a ! -f "$i/.disable_install" ]; then 
      ssh $remhost "cd hpchub_benchmark/$i; HPCHUB_PLATFORM=../../platforms/${platform}.sh ./install.sh" || exit 5
    fi
  done
  ssh $remhost "echo ok > hpchub_benchmark/install_ok"

elif [ "$operation" = "clean" ];then
  for i in tests/*; do
    if [ -x "$i/clean.sh" -a ! "$i" = "tests/include" ]; then 
       ssh $remhost "cd hpchub_benchmark/$i; HPCHUB_PLATFORM=../../platforms/${platform}.sh ./clean.sh"
    fi
  done
  ssh $remhost "rm -rf hpchub_benchmark"
else
  now=`date +%Y-%m-%d_%H:%M:%S`
  
  for i in tests/*; do
    if [ -x "$i/${operation}.sh" -a ! "$i" = "tests/include" -a ! -f "$i/.disable_run" ]; then 
       testname=${i##tests/}
       resdir="runs/${operation}/${testname}/${platform}/${now}"
       mkdir -p "$resdir"
       remreport=$remwd/hpchub_benchmark/${operation}_${testname}_${now}.log

       ssh $remhost "cd hpchub_benchmark/$i; HPCHUB_REPORT=${remreport} HPCHUB_PLATFORM=../../platforms/${platform}.sh ./${operation}.sh" | tee $resdir/out.log
       scp $remhost:$remreport $resdir/report.time.txt
    fi
  done
fi
