
export NNODES=2
export NCPU=$(($NNODES*16))
HPCHUB_PWD=`pwd`

if [ -f "$HPCHUB_PLATFORM" ]; then
  HPCHUB_PLATFORM_COMMON=${HPCHUB_PLATFORM%%azure-2-nodes-32-cores.sh}.azure.common.sh
else
  HPCHUB_PLATFORM_COMMON=${HPCHUB_PWD}/platform/.azure.common.sh
fi

if [ ! -f ${HPCHUB_PLATFORM_COMMON} ]; then
  echo "Azure common platform file not found! Can't resume."
  exit 1
fi

. ${HPCHUB_PLATFORM_COMMON}
