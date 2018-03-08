#!/bin/bash

source ${HOME}/usr/bin/GMXRC

export HPCHUB_TEST_STATE=run

if [ -f ../platform.sh ]; then
  . ../platform.sh
fi

## Gromacs has notice that optimal performance is obtained on
## 6 OpenMP threads + as many MPI as possible.
#HPCHUB_OPTIMAL_OMP=6 
#HPCHUB_BUILTIN_MPI=1

if [ -f "${HPCHUB_PLATFORM}" ]; then
  . ${HPCHUB_PLATFORM}
fi

if [ "${HPCHUB_REPORT}" = "" ]; then
  report_to=../report.time.txt
else
  report_to=${HPCHUB_REPORT}
fi

. ../include/logger.sh

mkdir molmod || echo "molmod already exists."
if [ $HPCHUB_PLATFORM == 'azure' ]; then
  for i in $NODES; do
    rsync -azP --delete ~/ $i:~/
  done
fi

gmx=`pwd`/gromacs-5.1.4/build/bin/gmx_mpi

cd molmod
rm \#*
if [ $HPCHUB_PLATFORM == 'azure' ]; then
  for i in $NODES; do
    rsync -azP --delete ~/ $i:~/
  done
fi

### 
#
# Gromacs refuses to run with > 6 OpenMP Cores,
# 
###


# http://www.bevanlab.biochem.vt.edu/Pages/Personal/justin/gmx-tutorials/lysozyme/01_pdb2gmx.html
#
#if [ "$OMP_NUM_THREADS" -gt 6 ]; then
#  OMP_NUM_THREADS=6
#fi

export OMP_NUM_THREADS=1

files="1AKI.pdb"

for p in $files; do
  prot=${p%%.pdb}
  gro=${prot}.gro
  top=${prot}.top
  mkdir ${prot}
  cd ${prot}

if [ -f "${HPCHUB_MACHINEFILE}" ];then
  cp "${HPCHUB_MACHINEFILE}" ./machinefile
else
  cp ../../machinefile ./
fi

  rm \#*
  if [ $HPCHUB_PLATFORM == 'azure' ]; then
    for i in $NODES; do
      rsync -azP --delete ~/ $i:~/
    done
  fi
  StepCntr=0
  LogStep $p Start 

  gmx pdb2gmx -f ../$p -o $gro -p $top -water spce -ff oplsaa 

  LogStep $p Step1-pdb2gmx

  gmx editconf -f $gro -o ${prot}_newbox.gro -c -d 1.0 -bt cubic

  LogStep $p Step2-editconf

  gmx solvate -cp ${prot}_newbox.gro -cs spc216.gro -o ${prot}_solv.gro -p $top 

  LogStep $p Step3-solvate

  gmx grompp -f ../../ions.mdp -c ${prot}_solv.gro -p $top -o ${prot}-ions.tpr 
  
  LogStep $p Step4-grompp

  if [ -f ../../${prot}-genion-stdin.txt ]; then
    N=`cat ../../${prot}-genion-stdin.txt`
  else
    N=13
  fi

  echo "$N" | gmx genion -s ${prot}-ions.tpr -o ${prot}_solv_ions.gro -p $top -pname NA -nname CL -nn 8 

  LogStep $p Step5-genion

  gmx grompp -f ../../minim.2.mdp -c ${prot}_solv_ions.gro -p $top -o ${prot}-em.tpr 
  if [ $HPCHUB_PLATFORM == 'azure' ]; then
    for i in $NODES; do
      rsync -azP --delete ~/ $i:~/
    done
  fi

  LogStep $p Step6-grompp

  ${HPCHUB_MPIRUN} $gmx mdrun -v -deffnm ${prot}-em 
  
  LogStep $p Step7-mdrun-em

  gmx grompp -f ../../nvt.2.mdp -c ${prot}-em.gro -p $top -o ${prot}-nvt.tpr 
  if [ $HPCHUB_PLATFORM == 'azure' ]; then
    for i in $NODES; do
      rsync -azP --delete ~/ $i:~/
    done
  fi

  LogStep $p Step8-grompp
 
  ${HPCHUB_MPIRUN}  $gmx mdrun -deffnm ${prot}-nvt

  LogStep $p Step9-mdrun-nvt

  gmx grompp -f ../../npt.mdp -c ${prot}-nvt.gro -t ${prot}-nvt.cpt -p $top -o ${prot}-npt.tpr
  if [ $HPCHUB_PLATFORM == 'azure' ]; then
    for i in $NODES; do
      rsync -azP --delete ~/ $i:~/
    done
  fi

  LogStep $p Step10-npt

  ${HPCHUB_MPIRUN}   $gmx mdrun -deffnm ${prot}-npt

  LogStep $p Step11-mdrun-npt

  gmx grompp -f ../../md.2.100.mdp -c ${prot}-npt.gro -t ${prot}-npt.cpt -p $top -o ${prot}-md_0_1.100.tpr

  gmx grompp -f ../../md.2.1000.mdp -c ${prot}-npt.gro -t ${prot}-npt.cpt -p $top -o ${prot}-md_0_1.1000.tpr

  gmx grompp -f ../../md.2.10000.mdp -c ${prot}-npt.gro -t ${prot}-npt.cpt -p $top -o ${prot}-md_0_1.10000.tpr
  if [ $HPCHUB_PLATFORM == 'azure' ]; then
    for i in $NODES; do
      rsync -azP --delete ~/ $i:~/
    done
  fi

  LogStep $p Step12-grompp

  for nsteps in 100 1000 10000; do 

    ${HPCHUB_MPIRUN}  $gmx mdrun -deffnm ${prot}-md_0_1.$nsteps 2>stderr.md.$nsteps.txt

    LogStep $p Step13-mdrun-prod-${nsteps} $nsteps

    perf=`grep Performance: stderr.md.$nsteps.txt | awk '{print $2;}'`
    imb=`grep "Average load imbalance:" stderr.md.$nsteps.txt | awk '{print $4;};'`
  
    LogStep $p Step13-mdrun-prod-${nsteps}-perf-ns_per_day $perf
    LogStep $p Step13-mdrun-prod-${nsteps}-imbalance-percentage $imb
 
  done
  cd ..
done
