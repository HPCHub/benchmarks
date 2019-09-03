#!/bin/bash
if [ -f ../platform.sh ]; then
  . ../platform.sh
fi
. include.sh

HPCHUB_TEST_STATE=install

if [ -f "${HPCHUB_PLATFORM}" ]; then
  . "${HPCHUB_PLATFORM}"
fi

if [ ! -f "${fio_fname}" ]; then
  wget "${fio_url}"
  tar -xvzf "${fio_fname}"
fi

test_dir=$(pwd)
hpchub_benchmark_dir="$(realpath "$test_dir/../../")"

cd "${fio_dir}"

${HPCHUB_COMPILE_PREFIX} ./configure --prefix="$test_dir/install"
${HPCHUB_COMPILE_PREFIX} make
#${HPCHUB_COMPILE_PREFIX} make install

chmod a+x "$test_dir/fiorun.sh"
cp "$test_dir/fiorun.sh" ./

PLATFORM_NAME="$(basename "$HPCHUB_PLATFORM" | sed -e "s/\..*//" )"
if [ "$HPCHUB_ISLOCAL" != "1" -a "$HPCHUB_ISNFS" != "1" ]; then
    if [ "$PLATFORM_NAME" = "azurer" -o "$PLATFORM_NAME" = "OCI" ]; then
        for i in $NODES; do
            ssh $i "mkdir -p $hpchub_benchmark_dir"
            scp -r ../../../tests  "$i:$hpchub_benchmark_dir/"
        done
    fi
fi
