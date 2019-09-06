#!/bin/bash

function help
{
    echo "Usage:"
    echo "  runat.sh [OPTIONS] [user@]HOST PLATFORM OPERATION [test]"
    echo "where"
    echo "  HOST - some HOST, that current user can log in into using 'ssh HOST' command"
    echo "         (hint: use ~/.ssh/config to set it up accordingly)"
    echo "  PLATFORM - platform, expected to exist on host. One of:"
    for platform in $(ls platforms/ | sed 's/.sh$//' | awk '{print $1;};'); do
        echo "      $platform"
    done
    echo "  OPERATION - one of: install run clean"
    echo "              (hint: after install one can call run multiple times)"
    echo "  test - optional test name. If present, only this test will be executed, if enabled"
    echo ""
    echo "Available options:"
    echo "  -d, --disable-nfs"
    echo "    Disable nfs usage (ignore platform_hook_nfs_dir)."
    echo "  -t, --tar-ball"
    echo "    Pack result to archive"
    echo "  -a, --analise"
    echo "    Auto analize OSU and NPB results to analize.out file"
}

function analise_req
{
    python -c "import numpy" >/dev/null 2>&1
    [ "$?" = "0" ] && return 0

    ch pip >/dev/null 2>&1
    [ "$?" != "0" ] && sudo yum -y install python2-pip

    sudo pip install --upgrade pip

    python -c "import numpy" >/dev/null 2>&1
    [ "$?" != "0" ] && sudo pip install numpy
}

disable_nfs="0"
tarball="0"
analise="0"

while [ "$#" -gt 0 ]; do
    key="$1"
    case $key in
        "-h"|"--help")
            help
            exit 0
            ;;
        "-d"|"--disable-nfs")
            disable_nfs="1"
            shift
            ;;
        "-t"|"--tar-ball")
            tarball="1"
            shift;
            ;;
        "-a"|"--analise")
            analise="1"
            shift;
            ;;
        -*)
            echo "[ERROR] Unrecognized option \"$key\""
            echo ""
            help
            exit 1
            ;;
        *)
            break;
            ;;
    esac
done

if [ "$analise" = "1" ]; then
    analise_req
fi

hpchub_benchmark_dir="hpchub_benchmark"

remhost="$1"
platform="$2"
operation="$3"
testopt="$4"
        
if [ "$remhost" = "" -o ! -f "platforms/${platform}.sh" -o "$operation" = "" ]; then
    help
    exit 1
fi

[ ! -d "runs" ] && mkdir runs

platform_hook_nfs_dir=""

if [ -f "local_platform_hooks/$platform.$operation.sh" ];then
  . "local_platform_hooks/$platform.$operation.sh"
fi

islocal="0"
isnfs="0"
remcomm="ssh $remhost"

if [ "$remhost" = "localhost" ]; then
  remhost="$(hostname)"
  islocal="1"
  curr_wd="$(pwd)"
  script_path="$0"
  full_path="$curr_wd/$script_path"
  remwd="$(realpath "$(dirname "$full_path")")"
  hpchub_benchmark_dir="$(basename "$remwd")"
  remwd="$(dirname "$remwd")"
  remcomm="eval"
  [ -n "$platform_hook_nfs_dir" -a "$disable_nfs" = "0" ] && isnfs="1"
fi


if [ "$islocal" != "1" ]; then
    if [ "$(echo "$platform_hook_nfs_dir" | grep "^/" -c)" = "1" -a "$disable_nfs" = "0" ]; then
        remwd="$platform_hook_nfs_dir"
        isnfs="1"
    else
        remwd="$($remcomm pwd)"
        if [ ! "$?" = "0" -o "$remwd" = "" ]; then
            echo "Problems connecting to host $remhost"
            exit 2
        fi
        if [ -n "$platform_hook_nfs_dir" -a "$disable_nfs" = "0" ]; then
            remwd=$remwd/$platform_hook_nfs_dir
            isnfs="1"
        fi
    fi
fi 

if [ "$testopt" = "" ]; then
  testset="tests/*"
else
  testset="tests/$testopt"
fi

if [ "$operation" = "install" ]; then
  if [ "$islocal" = "0" ]; then
    #tar -czf - . | ssh "$remhost" "cat > $remwd/hpchub_benchmark.tar.gz"
    git archive --format tar.gz master | ssh "$remhost" "cat > $remwd/hpchub_benchmark.tar.gz"
    $remcomm "(mkdir -p $remwd/${hpchub_benchmark_dir})" 
    $remcomm "(cd $remwd/${hpchub_benchmark_dir}; tar -xvzf ../hpchub_benchmark.tar.gz)" || exit 4
    echo "tarballs sent."
  else
    echo "Running on the localhost. Tarball sending will be skipped"
  fi

  for ctest in $testset; do
    if [ -d "$ctest" -a ! "$ctest" = "tests/include" -a ! -f "$ctest/.disable_install" ]; then
      $remcomm "(cd $remwd/${hpchub_benchmark_dir}/$ctest; HPCHUB_ISLOCAL=$islocal HPCHUB_ISNFS=$isnfs HPCHUB_PLATFORM=../../platforms/${platform}.sh ./install.sh)" || exit 5
    fi
  done

  $remcomm "(echo ok > $remwd/${hpchub_benchmark_dir}/install_ok)"

elif [ "$operation" = "clean" ];then

  for i in $testset; do
    if [ -x "$i/clean.sh" -a ! "$i" = "tests/include" ]; then 
       $remcomm "(cd $remwd/${hpchub_benchmark_dir}/$i; HPCHUB_ISLOCAL=$islocal HPCHUB_ISNFS=$isnfs HPCHUB_PLATFORM=../../platforms/${platform}.sh ./clean.sh)"
    fi
  done
  if [ "$islocal" != "1" ]; then
    $remcomm "(rm -rf $remwd/hpchub_benchmark.tar.gz)"
    $remcomm "(rm -rf $remwd/${hpchub_benchmark_dir})"
  fi

elif [ "$operation" = "run" ]; then
  now="$(date +%Y-%m-%d_%H:%M:%S)"
  now2="$(date +%Y%m%d_%H%M%S)"
  
  for ctest in $testset; do
    if [ -x "$ctest/${operation}.sh" -a ! "$ctest" = "tests/include" -a ! -f "$ctest/.disable_run" ]; then 
      testname=${ctest##tests/}
      resdir="runs/${operation}/${testname}/${platform}/${remhost}/${now}"
      mkdir -p "$resdir"
      remreport=$remwd/${hpchub_benchmark_dir}/${operation}_${testname}_${now}.log

      echo "Runing test: $testname"
      echo "expecting remote host $remhost to generate report at: ${remreport}"

      $remcomm "(cd $remwd/${hpchub_benchmark_dir}/$ctest; HPCHUB_OPERATION=${operation} HPCHUB_REPORT=${remreport} HPCHUB_RESDIR=${resdir} HPCHUB_ISLOCAL=${islocal} HPCHUB_ISNFS=$isnfs HPCHUB_PLATFORM=../../platforms/${platform}.sh ./${operation}.sh)" 2>&1 | tee "$resdir/out.log"

      if [ "$islocal" = "0" ]; then
        scp "$remhost":"$remreport" "$resdir/report.time.txt" || echo "report time not logged"
        if [ "$testname" == 'npb' -o "$testname" == 'osu' ]; then
            echo "Also fetching additional files: "
            scp "$remhost:$remwd/${hpchub_benchmark_dir}/$resdir/*" "$resdir"
        fi
      else
        cp "$remreport" "$resdir/report.time.txt" || echo "report time not logged"
        if [ "$testname" == 'npb' -o "$testname" == 'osu' ]; then
            echo "Also fetching additional files: "
            cp "$remwd/${hpchub_benchmark_dir}/$resdir"/* "$resdir"
        fi
      fi

      if [ "$analise" = "1" ]; then
          if [ "$testname" = "npb" ]; then
              ./analise_scripts/get_stat_npb.py "$resdir" | tee "$resdir/analize.out"
          elif [ "$testname" = "osu" ]; then
              ./analise_scripts/get_stat_osu.py "$resdir" | tee "$resdir/analize.out"
          fi
      fi
    
      if [ "$tarball" = "1" ]; then
        mkdir -p tarballs
        tarball_name="${platform}_${testname}_${remhost}_${now2}"
        mkdir "$tarball_name"
        cp -r "$resdir"/* "$tarball_name/"
        tar -czf "${tarball_name}.tar.gz" "$tarball_name"
        mv "${tarball_name}.tar.gz" ./tarballs/
        rm -rf "$tarball_name"
        echo "Tar ball with result: ./tarball/${tarball_name}.tar.gz" 
      fi
    fi
  done
else
    echo "Undefined operation \"$operation\": avalible operations is install run clean"
    exit 1
fi
