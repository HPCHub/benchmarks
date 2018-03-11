#!/bin/bash

if [ -f ../platform.sh ]; then
  . ../platform.sh
fi

HPCHUB_TEST_STATE=run

if [ -f "${HPCHUB_PLATFORM}" ]; then
  . ${HPCHUB_PLATFORM}
fi

if [ "${HPCHUB_REPORT}" = "" ]; then
  report_to=../report.time.txt
else
  report_to=${HPCHUB_REPORT}
fi

. ../include/logger.sh

cat /proc/cpuinfo

MHZ=`cat /proc/cpuinfo | grep MHz | tail -n 1 | awk '{print $4;}'`
bogomips=`cat /proc/cpuinfo | grep MHz | tail -n 1 | awk '{print $3;}'`
cache=`cat /proc/cpuinfo | grep "cache size" | tail -n 1 | awk '{print $4;}'`
family=`cat /proc/cpuinfo | grep "cpu family" | tail -n 1 | awk '{print $4;}'`
model=`cat /proc/cpuinfo | grep "model\s\s:" | tail -n 1 | awk '{print $3;}'`

LogStep cpuinfo MHZ $MHZ
LogStep cpuinfo bogomips $bogomips
LogStep cpuinfo cache_KB $cache
LogStep cpuinfo cpu_family $family
LogStep cpuinfo cpu_model $model

lspci
