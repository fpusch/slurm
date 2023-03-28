#!/bin/bash
# sample script running the IOR benchmark in file per process mode to simulate a parallelized application
#SBATCH --ntasks=8
#SBATCH --nodes=4
#SBATCH --partition=debug
#SBATCH --output=ior_mpm.out
#SBATCH --error=ior_mpm.err

# this is needed to run as root (I can't get other users working with lustre)
export OMPI_ALLOW_RUN_AS_ROOT=1
export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1

# 8 tasks
# 1 megabyte transfer size
# 16 megabytes per task
# 128 segments
mpirun -n 8 ior -t 1m -b 16m -s 128 -k -F -C -e

