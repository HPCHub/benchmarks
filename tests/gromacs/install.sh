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

CMAKE=`which cmake`
if [ ! -x "$CMAKE" ]; then
  wget https://cmake.org/files/v3.11/cmake-3.11.0-rc2.tar.gz
  tar -xvzf cmake-3.11.0-rc2.tar.gz
  cd cmake*
  ./configure --prefix=${HOME}/usr
  make -j10
  make install
  cd ..
  export PATH=${HOME}/usr/bin:${PATH}
fi

version=5.1.4
if [ ! -f gromacs-${version}.tar.gz ]; then
  wget ftp://ftp.gromacs.org/pub/gromacs/gromacs-${version}.tar.gz
fi
  
  tar -xvzf gromacs-${version}.tar.gz
  cd gromacs-${version}
  mkdir build
  cd build 
  CC=$MPICC CXX=$MPICXX cmake .. -DGMX_MPI=ON -DGMX_BUILD_OWN_FFTW=ON -DREGRESSIONTEST_DOWNLOAD=ON -DGMX_BUILD_OWN_FFTW=ON -DCMAKE_INSTALL_PREFIX=${HOME}/usr -DCMAKE_PREFIX_PATH=${HOME}/usr -DREGRESSIONTEST_DOWNLOAD=ON
  make
  make check
  make install
#   for compatibility with run.sh
  ln -s  ~/usr/bin/gmx_mpi ~/usr/bin/gmx
  

  if [ $HPCHUB_PLATFORM == 'azure' ]; then
    for i in $NODES; do
		rsync -azP --delete ~/ $i:~/
	done
  fi
  cd ../..
if [ ! -d molmod ]; then
  mkdir molmod
fi
cd molmod
files="1AKI.pdb"

for p in $files; do 
  if [ ! -f $p ] ; then
    wget https://files.rcsb.org/download/${p}.gz
    gzip -d ${p}.gz
  fi
  if [ $HPCHUB_PLATFORM == 'azure' ]; then
    for i in $NODES; do
      rsync -azP --delete ~/ $i:~/
    done
  fi
done


