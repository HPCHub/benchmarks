#!/bin/bash

if [ -f ../platform.sh ]; then
  . ../platform.sh
fi
. include.sh

HPCHUB_TEST_STATE=install

if [ -f "${HPCHUB_PLATFORM}" ]; then
  . ${HPCHUB_PLATFORM}
fi

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

if [ ! -f NPB${npb_version}.tar.gz ]; then
  wget https://www.nas.nasa.gov/assets/npb/NPB${npb_version}.tar.gz
  tar -xvzf NPB${npb_version}.tar.gz
fi

cd NPB${npb_version}/NPB3.3-MPI

#generate config for NPB
echo generate config for NPB
cp ./config/make.def.template ./config/make.def

sed -i 's@MPIF77 = .*@MPIF77 = '"$MPIFC"'@' ./config/make.def
sed -i 's@MPICC = .*@MPICC = '"$MPICC"'@' ./config/make.def
sed -i 's/FMPI_LIB.*/FMPI_LIB  =/' ./config/make.def
sed -i 's/FMPI_INC.*/FMPI_INC  =/' ./config/make.def

sed -i 's/CMPI_LIB.*/CMPI_LIB  =/' ./config/make.def
sed -i 's/CMPI_INC.*/CMPI_INC  =/' ./config/make.def
sed -i 's@CFLAGS.*@CFLAGS = -Ofast -mcmodel=medium@' ./config/make.def
sed -i 's@FFLAGS.*@FFLAGS = -Ofast -mcmodel=medium@' ./config/make.def
sed -i 's@FLINKFLAGS.*@FLINKFLAGS = -Ofast@' ./config/make.def
sed -i 's@CLINKFLAGS.*@CLINKFLAGS = -Ofast@' ./config/make.def

#generate build suit for NPB

echo NCPU=$NCPU
echo NNOCES=$NNODES
local_ncpus=$(($NCPU/$NNODES))

if [ -f ./config/suite.def ]; then
	rm ./config/suite.def
fi
i=1
while [ $i -le $local_ncpus ]; do
	echo is C $i >> ./config/suite.def
	echo lu C $i >> ./config/suite.def
	echo ft C $i >> ./config/suite.def
	echo mg C $i >> ./config/suite.def
	echo cg C $i >> ./config/suite.def
	echo ep C $i >> ./config/suite.def
	let i=i*2
done

i=1
j=1
while [ $j -le $local_ncpus ]; do
	echo sp C $j >> ./config/suite.def
	echo bt C $j >> ./config/suite.def
	let i=i+1
	let j=i*i
done

${HPCHUB_COMPILE_PREFIX} make clean
${HPCHUB_COMPILE_PREFIX} make suite

if [ $HPCHUB_PLATFORM == 'azure' ]; then
	for i in $NODES; do
		echo copying tests to $i:$HOME/hpchub_benchmark/
		scp -r ../../../../tests/  $i:$HOME/hpchub_benchmark/
	done
fi
