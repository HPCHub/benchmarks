#!/bin/bash

echo "Rescale platform is weird, and has no SSH access."
echo "Thus you will have to do some stuff in your web browser."
echo "First, I'll create a tarball for you:"
git archive --format tar master > master.tar
tar -rf master.tar `find -name '.disable*'`
gzip master.tar

echo "Here it is:"
ls -la master.tar.gz
echo "Now, create a new job in https://platform.rescale.com/jobs/new-job/"
echo "Upload this tarball as input file"
echo "Tap 'Bring your own MPI Software'"
echo "Enter the following as 'Command':"
cat << EOF
tar -xvzf master.tar.gz
for i in tests/*; do
  cd \$i 
  testname=\${i##tests/}
  if [ ! -f \$i/.disable_install ]; then
    HPCHUB_PLATFORM=../../platforms/rescale.sh ./install.sh
  fi
  if [ ! -f \$i/.disable_run ]; then 
    HPCHUB_OPERATION=run HPCHUB_REPORT=\`pwd\`/report.\$testname.txt HPCHUB_PLATFORM=../../platforms/rescale.sh ./run.sh
  fi
done

EOF

echo "When the job will be done, drop the files report.TESTNAME.txt in current directory:"
pwd
echo "And press enter (press Ctrl-C now to exit)"
read a

now=`date +%Y-%m-%d_%H:%M:%S`
for i in tests/*; do
  testname=${i##tests/}
  if [ -f report.$testname.txt ]; then
    echo "Ok, I see report.$testname.txt"
    resdir="runs/${operation}/${testname}/${platform}/${remhost}/${now}"
    mkdir -p "$resdir"
    echo "I will move it into $resdir/report.time.txt"
    mv report.$testname.txt $resdir/report.time.txt
  else
    echo "Ups, I don't see report.$testname.txt"
    echo "Hope it's OK"
  fi
done

exit
