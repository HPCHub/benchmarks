#!/bin/bash

if [ -f ../platform.sh ]; then
  . ../platform.sh
fi

HPCHUB_TEST_STATE=install

if [ -f "${HPCHUB_PLATFORM}" ]; then
  . ${HPCHUB_PLATFORM}
fi

fftw_version=3.3.7
if [ ! -f fftw-${fftw_version}.tar.gz ]; then 
  wget http://www.fftw.org/fftw-${fftw_version}.tar.gz
  tar -xvzf fftw-${fftw_version}.tar.gz 
  cd fftw-${fftw_version}
  ./configure --prefix=${HOME}/usr ${FFTW_CONFIGURE_FLAGS}
  make && make install
fi  

version=5.1.4
if [ ! -f gromacs-${version}.tar.gz ]; then
  wget ftp://ftp.gromacs.org/pub/gromacs/gromacs-${version}.tar.gz
fi
  tar -xvzf gromacs-${version}.tar.gz
  cd gromacs-${version}
  mkdir build
  cd build 
  cmake .. -DGMX_BUILD_OWN_FFTW=ON -DREGRESSIONTEST_DOWNLOAD=ON -DGMX_BUILD_OWN_FFTW=ON -DCMAKE_INSTALL_PREFIX=${HOME}/usr -DCMAKE_PREFIX_PATH=${HOME}/usr -DREGRESSIONTEST_DOWNLOAD=ON
  make
  make check
  make install

  if [ $HPCHUB_PLATFORM == 'azure' ]; then
    for i in $NODES; do
      scp -r ../../../../tests/  $i:$HOME/hpchub_benchmark/
	done
  fi
