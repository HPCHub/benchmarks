#!/bin/bash

if [ -f ../platform.sh ]; then
  . ../platform.sh
fi
. include.sh

HPCHUB_TEST_STATE=install

which pip >/dev/null 2>&1
[ "$?" != "0" ] && sudo yum -y install python2-pip

sudo pip install --upgrade pip

python -c "import numpy" >/dev/null 2>&1
[ "$?" != "0" ] && sudo pip install numpy


if [ -f "${HPCHUB_PLATFORM}" ]; then
  . ${HPCHUB_PLATFORM}
fi

test_dir=$(pwd)

if [ ! -f osu-micro-benchmarks-${osu_version}.tar.gz ]; then
  wget http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-${osu_version}.tar.gz 
fi

if [ ! -d osu-micro-benchmarks-${osu_version} ]; then
  tar -xvzf osu-micro-benchmarks-${osu_version}.tar.gz || exit 10
fi

cd osu-micro-benchmarks-${osu_version}

sed -i 's@{8, 16, 32, 64, 128}@{8, 16, 32, 64, 128, 256, 512}@' ./util/osu_util.h
sed -i 's@WINDOW_SIZES_COUNT   (5)@WINDOW_SIZES_COUNT   (7)@' ./util/osu_util.h

if [ ! -x $MPICC ]; then
	echo no MPICC
	exit 1
fi
if [ ! -x $MPICXX ]; then
	echo no MPICXX
	exit 1
fi
if [ ! -x $MPIFC ]; then
	echo no MPIFC
	exit 1
fi
if [ ! -x "$CC" ]; then
	echo no CC compiler
	exit 1
fi
if [ ! -x "$CXX" ]; then
	echo no CXX compiler
	exit 1
fi
${HPCHUB_COMPILE_PREFIX} ./configure  CC=$MPICC CXX=$MPICXX FC=$MPIFC

${HPCHUB_COMPILE_PREFIX} make
#make install

hpchub_benchmark_dir="$(realpath "$test_dir/../../")"

PLATFORM_NAME=$(basename "$HPCHUB_PLATFORM" | sed -e "s/\..*//" )
if [ "$HPCHUB_ISLOCAL" != "1" -a "$HPCHUB_ISNFS" != "1" ]; then
    if [ "$PLATFORM_NAME" = 'azure' -o "$PLATFORM_NAME" = "OCI" ]; then
        for i in $NODES; do
            ssh "$i" "mkdir -p $hpchub_benchmark_dir"
            scp -r ../../../tests  "$i:$hpchub_benchmark_dir/"
        done
    fi
fi
