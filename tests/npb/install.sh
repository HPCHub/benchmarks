#!/bin/bash

if [ -f ../platform.sh ]; then
  . ../platform.sh
fi
. include.sh

HPCHUB_TEST_STATE=install

if [ -f "${HPCHUB_PLATFORM}" ]; then
  . ${HPCHUB_PLATFORM}
fi

if [ ! -f NPB${npb_version}.tar.gz ]; then
  wget https://www.nas.nasa.gov/assets/npb/NPB${npb_version}.tar.gz
  tar -xvzf NPB${npb_version}.tar.gz
fi

cd NPB${npb_version}/NPB3.3-MPI

#generate config for NPB
echo generate config for NPB
cp ./config/make.def.template ./config/make.def

sed -i 's/MPIF77 = .*/MPIF77 = '"$FC"'/' ./config/make.def
sed -i 's/MPICC = .*/MPICC = '"$CC"'/' ./config/make.def
#sed -i 's/FMPI_LIB  = .*/FMPI_LIB  =' ./config/make.def
#sed -i 's/FMPI_INC  = .*/FMPI_INC  =' ./config/make.def

#sed -i 's/CMPI_LIB  = .*/CMPI_LIB  =' ./config/make.def
#sed -i 's/CMPI_INC  = .*/CMPI_INC  =' ./config/make.def
#sed -i 's/CFLAGS = .*/CFLAGS = -O3 --mcmodel=medium $FFTW_CONFIGURE_FLAGS' ./config/make.def
#sed -i 's/FFLAGS = .*/FFLAGS = -O3 --mcmodel=medium $FFTW_CONFIGURE_FLAGS' ./config/make.def

#generate build suit for NPB

if [ -f "${HPCHUB_MACHINEFILE}" ];then
	cp "${HPCHUB_MACHINEFILE}" ./machinefile
else
	cp ../machinefile ./
fi

local_ncpus=`cat machinefile | wc -l`

if [ -f suite.def ]; then
	rm suite.def
fi
i=1
while [ $i -le $local_ncpus ]; do
	echo is C $i >> suite.def
	echo lu C $i >> suite.def
	echo ft C $i >> suite.def
	echo mg C $i >> suite.def
	echo cg C $i >> suite.def
	echo ep C $i >> suite.def
	let i = i * 2
done

i=1
j=1
while [ $j -le $local_ncpus ]; do
	echo sp $i >> suite.def
	echo bt $i >> suite.def
	let i = i + 1
	let j = i * i
done

make clean
make suite
