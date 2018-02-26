#!/bin/bash

echo "Rescale platform is weird, and has no SSH access."
echo "Thus you will have to do some stuff in your web browser."
echo "First, I'll create a tarball for you:"
git archive --format tar master > master.tar
tar -rf master.tar `find -name '.disable*'`
now=`date +%Y-%m-%d_%H:%M:%S`
cat > rescale.sh << EOF
#!/bin/bash

tar -pcf rescale_result.tar rescale.sh
WD=\`pwd\`
for i in tests/*; do
  cd \$i 
  testname=\${i##tests/}
  export HPCHUB_RESDIR="\${WD}/runs/install/\${testname}/rescale/rescale/${now}"
  export HPCHUB_RESDIR_RELATIVE="runs/install/\${testname}/rescale/rescale/${now}"
  mkdir -p \${HPCHUB_RESDIR}
  if [ ! -f \$i/.disable_install ]; then
    HPCHUB_PLATFORM=../../platforms/rescale.sh ./install.sh > \${HPCHUB_RESDIR}/stdout.txt 2> \${HPCHUB_RESDIR}/stderr.txt
    (cd ../..;tar -rf rescale_result.tar \${HPCHUB_RESDIR_RELATIVE}/stdout.txt \${HPCHUB_RESDIR_RELATIVE}/stderr.txt)
  fi
  export HPCHUB_RESDIR="\${WD}/runs/run/\${testname}/rescale/rescale/${now}"
  mkdir -p \${HPCHUB_RESDIR}
  export HPCHUB_RESDIR_RELATIVE="runs/run/\${testname}/rescale/rescale/${now}"
  if [ ! -f \$i/.disable_run ]; then 
    HPCHUB_OPERATION=run HPCHUB_REPORT=\`pwd\`/report.\$testname.txt HPCHUB_PLATFORM=../../platforms/rescale.sh ./run.sh > \${HPCHUB_RESDIR}/stdout.txt 2> \${HPCHUB_RESDIR}/stderr.txt
    (cd ../..;tar -rf rescale_result.tar \${HPCHUB_RESDIR_RELATIVE}/stdout.txt \${HPCHUB_RESDIR_RELATIVE}/stderr.txt)
    tar -rf ../../rescale_result.tar report.\$testname.txt
  fi
  cd ../..
done

gzip rescale_result.tar

EOF
chmod a+x rescale.sh

tar -rf master.tar rescale.sh


gzip master.tar

echo "Here it is:"
ls -la master.tar.gz
echo "Now, create a new job in https://platform.rescale.com/jobs/new-job/"
echo "Upload this tarball as input file"
echo "Tap 'Bring your own MPI Software'"
echo "Enter the following as 'Command':"
echo 
echo "tar -xvzf master.tar.gz"
echo "./rescale.sh"
echo
echo "When the job will be done, drop the files report.TESTNAME.txt in current directory (or just unpack rescale_result.tar.gz):"
pwd
echo "And press enter (press Ctrl-C now to exit)"
read a

for i in tests/*; do
  testname=${i##tests/}
  if [ -f report.$testname.txt ]; then
    echo "Ok, I see report.$testname.txt"
    resdir="runs/run/${testname}/${platform}/${remhost}/${now}"
    mkdir -p "$resdir"
    echo "I will move it into $resdir/report.time.txt"
    mv report.$testname.txt $resdir/report.time.txt
  else
    echo "Ups, I don't see report.$testname.txt"
    echo "Hope it's OK"
  fi
done

exit
