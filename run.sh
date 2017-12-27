#!/bin/bash

source ${HOME}/usr/bin/GMXRC

cd gromacs-5.1.4
time -o time.report make check > make.check.log 2>make.check.err

cd ..

mkdir molmod || echo "molmod already exists."
cd molmod
rm \#*

# http://nmr.chem.uu.nl/~tsjerk/course/molmod/
#
# Requires some changes to use with recent gromacs versions!
# 

files="1Y6L.pdb"
for p in $files; do 
  if [ ! -f $p ] ; then
    wget https://files.rcsb.org/download/${p}.gz
    gzip -d ${p}.gz
  fi
done

for p in $files; do
  prot=${p%%.pdb}
  gro=${prot}.gro
  top=${prot}.top
  mkdir ${prot}
  cd ${prot}
  gmx pdb2gmx -f ../$p -o $gro -p $top -ignh -ff amber03 -water tip3p|| exit 1
 
  if [ ! -f minim.mdp -o ../../minim.mdp -nt ./minim.mdp ]; then
    cp ../../minim.mdp ./minim.mdp
  fi
  
  gmx grompp -f minim.mdp -c $gro -p $top -o ${prot}-EM-vacuum.tpr || exit 2

  gmx mdrun -v -deffnm ${prot}-EM-vacuum -c ${prot}-EM-vacuum.pdb || exit 3

  gmx editconf -f ${prot}-EM-vacuum.pdb -o ${prot}-PBC.gro -bt dodecahedron -d 1.0 || exit 4

  #gmx genbox -cp ${prot}-PBC.gro -cs spc216.gro -p $top -o ${prot}-water.pdb || exit 5
  gmx solvate -cp ${prot}-PBC.gro -cs spc216.gro -p $top -o ${prot}-water.pdb || exit 5

  gmx grompp -v -f minim.mdp -c ${prot}-water.pdb -p $top -o ${prot}-water.tpr || exit 6
 
  



  cd ..
done
