#!/bin/bash

if [ -f ../platform.sh ]; then
  . ../platform.sh
fi
. include.sh

HPCHUB_TEST_STATE=install

if [ -f "${HPCHUB_PLATFORM}" ]; then
  . ${HPCHUB_PLATFORM}
fi

if [ ! -f ${fio_fname} ]; then
  wget ${fio_url}
  tar -xvzf ${fio_fname}
fi

cd ${fio_dir}

${HPCHUB_COMPILE_PREFIX} ./configure --prefix=${HOME}/usr
${HPCHUB_COMPILE_PREFIX} make
${HPCHUB_COMPILE_PREFIX} make install


