
NNODES=2
NCPU=48

if [ -f "$HPCHUB_PLATFORM" ]; then
  HPCHUB_PLATFORM_COMMON=${HPCHUB_PLATFORM%%penguin-2-nodes-12-cores.sh}.penguin.common.sh
else
  HPCHUB_PLATFORM_COMMON=../.penguin.common.sh
fi

if [ ! -f ${HPCHUB_PLATFORM_COMMON} ]; then
  echo "Penguin common platform file not found! Can't resume."
  exit 1
fi

. ${HPCHUB_PLATFORM_COMMON}
