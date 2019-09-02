#!/bin/bash

if [ -f ../platform.sh ]; then
  . ../platform.sh
fi
. include.sh

HPCHUB_TEST_STATE=install

if [ -f "${HPCHUB_PLATFORM}" ]; then
  . ${HPCHUB_PLATFORM}
fi

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

PLATFORM_NAME=$(basename "$HPCHUB_PLATFORM" | sed -e "s/\..*//" )
if [ "$PLATFORM_NAME" == "azurer" -o -o "$PLATFORM_NAME" = "OCI" ]; then
	for i in $NODES; do
		scp -r ../../../tests/  $i:$HOME/hpchub_benchmark/
	done
fi
#make install
