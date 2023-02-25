#!/usr/bin/env bash
set -e
apt install munge libmunge-dev lua5.3 liblua5.3-dev -y
git clone -b slurm-21-08-6-1 --single-branch --depth=1 https://github.com/SchedMD/slurm.git
cd slurm
./configure --enable-debug --sysconfdir=/etc/slurm
make install
groupadd -r slurm
useradd -r -g slurm slurm
mkdir /var/spool/slurmd \
    /var/spool/slurmctld \
    /var/run/slurmd \
    /var/lib/slurmd \
    /var/log/slurm
chown -R slurm:slurm /var/spool/slurmd
chown -R slurm:slurm /var/spool/slurmctld
chown -R slurm:slurm /var/run/slurmd
chown -R slurm:slurm /var/lib/slurmd
chown -R slurm:slurm /var/log/slurm
chown -R slurm:slurm /usr/local/lib/slurm
chown -R slurm:slurm /etc/slurm/
