#!/bin/bash

source ${HOME}/usr/bin/GMXRC

if [ -f ../platform.sh ]; then
  . ../platform.sh
fi

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

wget http://www.bevanlab.biochem.vt.edu/Pages/Personal/justin/gmx-tutorials/complex/Files/em.mdp
wget -O 3HTB_clean.pdb http://www.bevanlab.biochem.vt.edu/Pages/Personal/justin/gmx-tutorials/complex/Files/3HTB_clean.pdb
files="3HTB.pdb"
grep JZ4 3HTB_clean.pdb > JZ4.pdb
grep -v JZ4 3HTB_clean.pdb >  3HTB.pdb


Tprev=`date +%s.%N`

function LogStep {
   local T0=`date +%s.%N`
   dT=`echo "$T0 - $Tprev" | bc -l`
   echo -ne "${p}\t$1\t$dT\t$T0\n" >> ../report.time.txt
   Tprev=$T0
}

echo -ne "Protein\tStep\tdT\tTimeStamp\n" > report.time.txt

for p in $files; do
  prot=${p%%.pdb}
  gro=${prot}.gro
  top=${prot}.top
  mkdir ${prot}
  cd ${prot}
  rm \#*
  LogStep Start 
  if [ "$SKIP" = "" ]; then
  
#  gmx pdb2gmx -f ../$p -o $gro -p $top -ignh -ff amber03 -water tip3p|| exit 1
  gmx pdb2gmx -f ../$p -o $gro -p $top -water spc -ff gromos43a1 || exit 1
#  gmx pdb2gmx -f ../$p -o $gro -p $top -water spc || exit 1
  LogStep Step1-pdb2gmx

  if [ ! -f minim.mdp -o ../../minim.mdp -nt ./minim.mdp ]; then
    cp ../../minim.mdp ./minim.mdp
  fi

  # gro+top -> tpr
    
  gmx grompp -f minim.mdp -c $gro -p $top -o ${prot}-EM-vacuum.tpr || exit 2

  LogStep Step2-grompp

  # ENERGY MINIMIZATION OF THE STRUCTURE (VACUUM) 
  # 500 steps.

  gmx mdrun -v -deffnm ${prot}-EM-vacuum -c ${prot}-EM-vacuum.pdb || exit 3

  LogStep Step3-mdrun
  
  # PERIODIC BOUNDARY CONDITIONS

  gmx editconf -f ${prot}-EM-vacuum.pdb -o ${prot}-PBC.gro -bt dodecahedron -d 1.0 || exit 4
#  gmx editconf -f ${prot}-EM-vacuum.pdb -o ${prot}-PBC.gro -bt cubic -d 1.0 || exit 4

  LogStep Step4-editconf-pbc

  #gmx genbox -cp ${prot}-PBC.gro -cs spc216.gro -p $top -o ${prot}-water.pdb || exit 5
  
  # SOLVENT ADDITION


  gmx solvate -cp ${prot}-PBC.gro -cs spc216.gro -p $top -o ${prot}-water.gro  || exit 5
  
  LogStep Step5-solvate

  # pdb+top -> tpr

  gmx grompp -v -f minim.mdp -c ${prot}-water.pdb -p $top -o ${prot}-water.tpr || exit 6

  LogStep Step6-grompp
  
  # ADDITION OF IONS: COUNTER CHARGE AND CONCENTRATION

  echo gmx genion -s ${prot}-water.tpr -o ${prot}-solvated.pdb -conc 0.15 -neutral -pname NA -nname CL 
  if [ -f ../../${prot}-genion-stdin.txt ]; then
    N=`cat ../../${prot}-genion-stdin.txt`
  else
    N=1
  fi
  echo "genion - N=$N"
  echo "$N" | gmx genion -s ${prot}-water.tpr -o ${prot}-solvated.pdb -p $top -conc 0.05 -neutral -pname NA -nname CL || exit 7 
  
  LogStep Step7-genion

  # top+pdb -> tpr
  
  gmx grompp -v -f minim.mdp -c ${prot}-solvated.pdb -p $top -o ${prot}-EM-solvated.tpr || exit 8

  LogStep Step8-grompp

  # ENERGY MINIMIZATION OF THE SOLVATED SYSTEM
  
  gmx mdrun -v -deffnm ${prot}-EM-solvated -c ${prot}-EM-solvated.pdb || exit 9

  LogStep Step9-mdrun-emin
 
  # RELAXATION OF SOLVENT AND HYDROGEN ATOM POSITIONS: POSITION RESTRAINED MD
  fi

  gmx grompp -v -f ../../pr.mdp -c ${prot}-EM-solvated.pdb -p $top -o ${prot}-PR.tpr || exit 10
  
  LogStep Step10-grompp

  gmx mdrun -v -deffnm ${prot}-PR || exit 11
 
  LogStep Step11-mdrun-solvent-relax

  #  UNRESTRAINED MD SIMULATION, TURNING ON TEMPERATURE COUPLING

  gmx grompp -v -f nvt.mdp -c ${prot}-PR.gro -p $top -o ${prot}-NVT.tpr || exit 12

  LogStep Step12-grompp

  gmx mdrun -v -deffnm ${prot}-NVT || exit 13

  LogStep Step13-mdrun-nvt

  # UNRESTRAINED MD SIMULATION, TURNING ON PRESSURE COUPLING

  gmx grompp -v -f npt.mdp -c ${prot}-NVT.gro -p $top -o ${prot}-NPT.tpr || exit 14

  LogStep Step14-grompp

  gmx mdrun -deffnm ${prot}-NPT || exit 15

  LogStep Step15-mdrun-npt

  # PRODUCTION SIMULATION
 
  gmx  grompp -f md.mdp -c ${prot}-NPT.gro -p $top -o ${prot}-topol.tpr || exit 16

  LogStep Step16-grompp
  
  gmx mdrun -deffnm ${prot}-topol.tpr || exit 17

  LogStep Step17-mdrun-production

  


  cd ..
done
