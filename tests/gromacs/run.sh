#!/bin/bash

source ${HOME}/usr/bin/GMXRC

if [ -f ../platform.sh ]; then
  . ../platform.sh
fi

if [ -f "${HPCHUB_PLATFORM}" ]; then
  . ${HPCHUB_PLATFORM}
fi

if [ "${HPCHUB_REPORT}" = "" ]; then
  report_to=../report.time.txt
else
  report_to=${HPCHUB_REPORT}
fi


mkdir molmod || echo "molmod already exists."
cd molmod
rm \#*

# http://www.bevanlab.biochem.vt.edu/Pages/Personal/justin/gmx-tutorials/lysozyme/01_pdb2gmx.html
#

files="1AKI.pdb"
for p in $files; do 
  if [ ! -f $p ] ; then
    wget https://files.rcsb.org/download/${p}.gz
    gzip -d ${p}.gz
  fi
done

Tprev=`date +%s.%N`

function LogStep {
   ret=$?
   if [ "$ret" -gt "0" ]; then
      echo "Step $StepCntr failed"
      exit $ret
   else
      StepCntr=$((StepCntr+1))
   fi
   local T0=`date +%s.%N`
   dT=`echo "$T0 - $Tprev" | bc -l`
   echo -ne "${p}\t$1\t$dT\t$T0\n" >> $report_to
   Tprev=$T0
}

echo -ne "Protein\tStep\tdT\tTimeStamp\n" > $report_to

for p in $files; do
  prot=${p%%.pdb}
  gro=${prot}.gro
  top=${prot}.top
  mkdir ${prot}
  cd ${prot}
  rm \#*
  StepCntr=0
  LogStep Start 

  gmx pdb2gmx -f ../$p -o $gro -p $top -water spce -ff oplsaa 

  LogStep Step1-pdb2gmx

  gmx editconf -f $gro -o ${prot}_newbox.gro -c -d 1.0 -bt cubic

  LogStep Step2-editconf

  gmx solvate -cp ${prot}_newbox.gro -cs spc216.gro -o ${prot}_solv.gro -p $top 

  LogStep Step3-solvate

  gmx grompp -f ../../ions.mdp -c ${prot}_solv.gro -p $top -o ${prot}-ions.tpr 
  
  LogStep Step4-grompp

  if [ -f ../../${prot}-genion-stdin.txt ]; then
    N=`cat ../../${prot}-genion-stdin.txt`
  else
    N=13
  fi

  echo "$N" | gmx genion -s ${prot}-ions.tpr -o ${prot}_solv_ions.gro -p $top -pname NA -nname CL -nn 8 

  LogStep Step5-genion

  gmx grompp -f ../../minim.2.mdp -c ${prot}_solv_ions.gro -p $top -o ${prot}-em.tpr 

  LogStep Step6-grompp

  gmx mdrun -v -deffnm ${prot}-em 
  
  LogStep Step7-mdrun-em

  gmx grompp -f ../../nvt.2.mdp -c ${prot}-em.gro -p $top -o ${prot}-nvt.tpr 

  LogStep Step8-grompp
 
  gmx mdrun -deffnm ${prot}-nvt

  LogStep Step9-mdrun-nvt

  gmx grompp -f ../../npt.mdp -c ${prot}-nvt.gro -t ${prot}-nvt.cpt -p $top -o ${prot}-npt.tpr

  LogStep Step10-npt

  gmx mdrun -deffnm ${prot}-npt

  LogStep Step11-mdrun-npt

  gmx grompp -f ../../md.2.100.mdp -c ${prot}-npt.gro -t ${prot}-npt.cpt -p $top -o ${prot}-md_0_1.100.tpr

  gmx grompp -f ../../md.2.1000.mdp -c ${prot}-npt.gro -t ${prot}-npt.cpt -p $top -o ${prot}-md_0_1.1000.tpr

  gmx grompp -f ../../md.2.1000.mdp -c ${prot}-npt.gro -t ${prot}-npt.cpt -p $top -o ${prot}-md_0_1.10000.tpr

  LogStep Step12-grompp

  gmx mdrun -deffnm ${prot}-md_0_1.100
   
  LogStep Step13-mdrun-prod-100

  gmx mdrun -deffnm ${prot}-md_0_1.1000
   
  LogStep Step13-mdrun-prod-1000

  gmx mdrun -deffnm ${prot}-md_0_1.10000
 
  LogStep Step13-mdrun-prod-10000

  cd ..
done
