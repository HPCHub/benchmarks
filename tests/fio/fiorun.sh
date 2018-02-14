#!/bin/bash
op=$1

${HOME}/usr/bin/fio --name=global --rw=$op --size=128m --output=job.${HOSNAME} --name=box.${HOSTNAME} 

