#!/bin/bash

source ${HOME}/usr/bin/GMXRC

cd gromacs-5.1.4
time -o time.report make check > make.check.log 2>make.check.err

cd ..

mkdir molmod || echo "molmod already exists."
cd molmod

# http://nmr.chem.uu.nl/~tsjerk/course/molmod/

files="1Y6L.pdb 3BZH.pdb"
for p in $files; do 
  if [ ! -f $p ] ; then
    wget https://files.rcsb.org/download/${p}.gz
    gzip -d ${p}.gz
  fi
done

for p in $files; do
  gro=${p%%.pdb}.gro
  top=${p%%.pdb}.top
  gmx pdb2gmx -f $p -o $gro -p $top -ignh -ff amber03 -water tip3p|| exit 1
 
  if [ ! -f minim.mdp ]; then
    wget http://nmr.chem.uu.nl/~tsjerk/course/molmod/minim.mdp
  fi
  
  gmx grompp -f minim.mdp -c $gro -p $top -o ${p%%.pdb}-EM-vacuum.tpr || exit 2

  gmx mdrun -v -deffnm ${p%%.pdb}-EM-vacuum -c ${p%%.pdb}-EM-vacuum.pdb || exit 3

done
