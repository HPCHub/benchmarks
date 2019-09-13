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
	[ "$?" != "0" ] && echo "Unable to connect to ${fio_url}" && exit 1
	[ ! -e "${fio_fname}" ] && echo "File ${fio_fname} does not exist" && exit 1
	tar -xvzf "${fio_fname}"
	[ "$?" != "0" ] && echo "Unable to unpack the ${fio_fname} file" && exit 1
fi

test_dir=$(pwd)
hpchub_benchmark_dir="$(realpath "$test_dir/../../")"

cd "${fio_dir}"

${HPCHUB_COMPILE_PREFIX} ./configure --prefix="$test_dir/install"
[ "$?" != "0" ] && echo "Problem with configuring fio utility" && exit 1
${HPCHUB_COMPILE_PREFIX} make
[ "$?" != "0" ] && echo "Problem with making fio utility" && exit 1
#${HPCHUB_COMPILE_PREFIX} make install

[ ! -e "$test_dir/fiorun.sh" ] && echo "File $test_dir/fiorun.sh does not exist" && exit 1
chmod a+x "$test_dir/fiorun.sh"
cp "$test_dir/fiorun.sh" ./

PLATFORM_NAME="$(basename "$HPCHUB_PLATFORM" | sed -e "s/\..*//" )"
if [ "$HPCHUB_ISLOCAL" != "1" -a "$HPCHUB_ISNFS" != "1" ]; then
	is_fail=0
    if [ "$PLATFORM_NAME" = "azurer" -o "$PLATFORM_NAME" = "OCI" ]; then
        for i in $NODES; do
            ssh $i "mkdir -p $hpchub_benchmark_dir"
			[ "$?" != "0" ] && is_fail="1"
            scp -r ../../../tests  "$i:$hpchub_benchmark_dir/"
			[ "$?" != "0" ] && is_fail="1"
        done
    fi
	[ "$is_fail" != "0" ] && echo "Fail with  files propagation" && exit 1
fi
