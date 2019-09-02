#!/bin/bash

# $1 command
function rexec
{
	if [ "$islocal" = "1" ]; then
		$1
	else
		$remcomm "$1"
	fi
}

if [ "$1" = "" -o ! -f "platforms/${2}.sh" -o "$3" = "" ]; then
  echo "Usage:"
  echo "  runat.sh [user@]HOST PLATFORM OPERATION [test]"
  echo "where"
  echo "  HOST - some HOST, that current user can log in into using 'ssh HOST' command"
  echo "         (hint: use ~/.ssh/config to set it up accordingly)"
  echo "  PLATFORM - platform, expected to exist on host. One of:"
  ls platforms/ | sed 's/.sh$//' | awk '{print $1;};'
  echo "  OPERATION - one of: install run clean"
  echo "              (hint: after install one can call run multiple times)"
  echo "  test - optional test name. If present, only this test will be executed, if enabled"
  exit 1
fi

if [ ! -d "runs" ]; then 
  mkdir runs
fi

hpchub_benchmark_dir="hpchub_benchmark"

remhost="$1"
platform="$2"
operation="$3"
testopt="$4"

platform_hook_nfs_dir=""

if [ -f "local_platform_hooks/$platform.$operation.sh" ];then
  . local_platform_hooks/$platform.$operation.sh
fi

islocal="0"
remcomm="ssh $remhost"

if [ "$remhost" = "localhost" ]; then
  remhost="$(hostname)"
  islocal="1"
  curr_wd="$(pwd)"
  script_path="$0"
  full_path="$curr_wd/$script_path"
  remwd="$(realpath $(dirname "$full_path"))"
  hpchub_benchmark_dir="$(basename $remwd)"
  remwd="$(dirname "$remwd")"
  remcomm="eval"
fi


if [ "$islocal" != "1" ]; then
	remwd="$($remcomm pwd)"
	if [ ! "$?" = "0" -o "$remwd" = "" ]; then
		echo "Problems connecting to host $remhost"
		exit 2
	fi
	remwd=$remwd/$platform_hook_nfs_dir
fi

if [ "$testopt" = "" ]; then
  testset=tests/*
else
  testset=tests/$testopt
fi

if [ "$operation" = "install" ]; then
  if [ "$islocal" = "0" ]; then
    tar -czf - . | ssh $remhost "cat > $remwd/hpchub_benchmark.tar.gz"
    #git archive --format tar.gz master | ssh $remhost "cat > $remwd/hpchub_benchmark.tar.gz"
    $remcomm "mkdir -p $remwd/${hpchub_benchmark_dir}" 
    $remcomm "cd $remwd/${hpchub_benchmark_dir}; tar -xvzf ../hpchub_benchmark.tar.gz" || exit 4
    echo "tarballs sent."
  else
    echo "Running on the localhost. Tarball sending will be skipped"
  fi

  for ctest in $testset; do
    if [ -d "$ctest" -a ! "$ctest" = "tests/include" -a ! -f "$ctest/.disable_install" ]; then
      $remcomm "cd $remwd/${hpchub_benchmark_dir}/$ctest; HPCHUB_ISLOCAL=$islocal HPCHUB_PLATFORM=../../platforms/${platform}.sh ./install.sh" || exit 5
    fi
  done

  $remcomm "echo ok > $remwd/${hpchub_benchmark_dir}/install_ok"

elif [ "$operation" = "clean" ];then
  if [ "$islocal" = "1" ]; then
    echo "FIXIT. The cleanup action on the local machine may be unsafe"
    exit 0
  fi

  for i in $testset; do
    if [ -x "$i/clean.sh" -a ! "$i" = "tests/include" ]; then 
       $remcomm "cd $remwd/${hpchub_benchmark_dir}/$i; HPCHUB_PLATFORM=../../platforms/${platform}.sh ./clean.sh"
    fi
  done
  $remcomm "rm -rf $remwd/${hpchub_benchmark_dir}"

elif [ "$operation" = "run" ]; then
  now=`date +%Y-%m-%d_%H:%M:%S`
  
  for ctest in $testset; do
    if [ -x "$ctest/${operation}.sh" -a ! "$ctest" = "tests/include" -a ! -f "$ctest/.disable_run" ]; then 
      testname=${ctest##tests/}
      resdir="runs/${operation}/${testname}/${platform}/${remhost}/${now}"
      mkdir -p "$resdir"
      remreport=$remwd/${hpchub_benchmark_dir}/${operation}_${testname}_${now}.log

      echo "Runing test: $testname"
      echo "expecting remote host $remhost to generate report at: ${remreport}"

      $remcomm "cd $remwd/${hpchub_benchmark_dir}/$ctest; HPCHUB_OPERATION=${operation} HPCHUB_REPORT=${remreport} HPCHUB_RESDIR=${resdir} HPCHUB_ISLOCAL=${islocal} HPCHUB_PLATFORM=../../platforms/${platform}.sh ./${operation}.sh" 2>&1 | tee $resdir/out.log

      if [ "$islocal" = "0" ]; then
        scp $remhost:$remreport $resdir/report.time.txt || echo "report time not logged"
        if [ $testname == 'npb' -o $testname == 'osu' ]; then
            echo "Also fetching additional files: "
            scp $remhost:$remwd/${hpchub_benchmark_dir}/$resdir/* $resdir
        fi
      fi
    fi
  done
else
    echo "Undefined operation \"$operations\": avalible operations is install run clean"
    exit 1
fi
