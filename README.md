# HPCHub benchmarks set.

- Purpose: arrange set of different general and task-oriented tests to be able to compare
performance of different cloud HPC solutions/configurations.

- Idea: separate platform-specific setups from task/test-specific code. Thus we have two 
directories: platforms and tests.

platforms contain one include .sh file for platform, which set environment variables, needed 
to install, compile and run tests on target platform.

tests contain one folder per test, which is expected to have at least two files:

- install.sh and run.sh - these files are to be run on target platform from corresponding 
directory with HPCHUB_PLATFORM environment variable, containing path to required platform.sh 
file.

These files are expected to set HPCHUB_TEST_STATE environment variable into "install" or "run"
state respectively before sourcing platform file.

As for now (may be changed!) run.sh is expected to wait for filename in HPCHUB_REPORT for 
filename for a file to log the results (see corresponding run.sh in gromacs test).

doc directory contains documents, related to current discussion state of the project and all 
other required documents.

Results are to be stored in "runs" directory.

Hints: 

 - If you want to skip some operation (OP) on some test, you can create empty .disable_OP (e.g. .disable_run or .disable_install) in this test's directory.

## Top-level tools

Top-level tools are supposed to be used for high-level operations. 
All of them output simple help when invoked without arguments.

As for now, we have 3 of them:

runat.sh - run enabled operation on some host assuming it operates some platform. Store results locally on success.

test - enable/disable tests

analise - obtain all the results gathered as a single table.

## WiKi

Full documentation on this project is maintained in wiki: https://github.com/HPCHub/benchmarks/wiki
