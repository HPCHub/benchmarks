#!/bin/bash

echo "Rescale platform is weird, and has no SSH access."
echo "Thus you will have to do some stuff in your web browser."
echo "First, I'll create a tarball for you:"
git archive --format tar.gz master > master.tar.gz
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
  HPCHUB_PLATFORM=../../platforms/rescale.sh ./install.sh
  HPCHUB_OPERATION=run HPCHUB_REPORT=\`pwd\`/report.\$testname.txt HPCHUB_PLATFORM=../../platforms/rescale.sh ./run.sh
done

EOF

exit
