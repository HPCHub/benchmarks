#!/bin/bash
DV=`cat /etc/debian_version`

if [ "$DV" = "stretch/sid" ]; then
## see https://openfoam.org/download/5-0-ubuntu/
  
sudo add-apt-repository http://dl.openfoam.org/ubuntu
sudo sh -c "wget -O - http://dl.openfoam.org/gpg.key | apt-key add -"

sudo apt-get update

sudo apt-get -y install openfoam5

fi
