#!/bin/bash

if [ "$1" = "" -o ! -f ../platforms/${2}.sh ]; then 
	echo "Usage:"
	echo "  azure.system-install.sh [user@]HOST PLATFORM"
	echo "where"
	echo "  HOST - some HOST, that current user can log in into using 'ssh HOST' command"
	echo "         (hint: use ~/.ssh/config to set it up accordingly)"
	echo "  PLATFORM - platform, expected to exist on host. One of:"
	ls ../platforms/azure* | sed  's/..\/platforms\// /'#| awk '{print $1;};'
	exit 1
fi

remhost=$1
platform=$2 

git archive --format tar.gz master | ssh $remhost "cat > hpchub_benchmark.tar.gz"
ssh $remhost "mkdir hpchub_benchmark"
ssh $remhost "cd hpchub_benchmark; tar -xvzf ../hpchub_benchmark.tar.gz" || exit 4
echo "tarballs sent."

operation="install_system"


if [ "$operation" = "install_system" ]; then
	ssh $remhost "cd hpchub_benchmark/; chmod +x ./platforms/${platform}.sh"
	ssh $remhost "cd hpchub_benchmark/; HPCHUB_PLATFORM=./platforms/${platform}.sh HPCHUB_OPERATION=install_system ./platforms/${platform}.sh" || exit 5
fi

