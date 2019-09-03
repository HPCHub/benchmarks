#!/bin/bash
if [ -f ../platform.sh ]; then
  . ../platform.sh
fi

. include.sh

HPCHUB_TEST_STATE=clean

if [ -f "${HPCHUB_PLATFORM}" ]; then
  . "${HPCHUB_PLATFORM}"
fi

if [ "$HPCHUB_ISNFS" = "1" ]; then
    PLATFORM_NAME="$(basename "$HPCHUB_PLATFORM" | sed -e "s/\..*//" )"
    if [ -f "../../local_platform_hooks/${PLATFORM_NAME}.run.sh" ]; then
        platform_hook_nfs_dir="$(. "../../local_platform_hooks/${PLATFORM_NAME}.run.sh"; echo "$platform_hook_nfs_dir")"
    else
        echo "Unable to find the file $(pwd)/../../local_platform_hooks/${PLATFORM_NAME}.run.sh, but HPCHUB_ISNFS=$HPCHUB_ISNFS"
        exit 1
    fi
    if [ "$(echo "$platform_hook_nfs_dir" | grep "^/" -c)" = "1" ]; then
        nfs_dir="$platform_hook_nfs_dir"
    else
        nfs_dir="$(pwd)/$platform_hook_nfs_dir"
    fi
fi

rm -rf "${fio_dir}"
[ -n "$nfs_dir" ] && rm -rf "$nfs_dir/fio"

test_dir=$(pwd)
hpchub_benchmark_dir="$(realpath "$test_dir/../../")"

if [ "$hpchub_benchmark_dir" = "/" ]; then
    echo "ERORR!!! hpchub_benchmark_dir=$hpchub_benchmark_dir, skip clean"
fi

PLATFORM_NAME="$(basename "$HPCHUB_PLATFORM" | sed -e "s/\..*//" )"
if [ "$HPCHUB_ISLOCAL" != "1" -a "$HPCHUB_ISNFS" != "1" ]; then
    if [ "$PLATFORM_NAME" = "azurer" -o "$PLATFORM_NAME" = "OCI" ]; then
        for i in $NODES; do
            ssh "$i" "rm -rf $hpchub_benchmark_dir"
        done
    fi
fi
