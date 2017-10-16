#!/bin/bash


setenforce 0
lftp 172.25.254.250 << ENO
cd /notes/project/UP200/UP200_cacti-master
mirror pkg/
ENO


cd pkg/
yum -y localinstall *.rpm

lftp 172.25.254.250 << EOT
cd /notes/project/software/nagios
get nrpe-2.12.tar.gz
EOT

yum -y install xinetd
tar -xf nrpe-2.12.tar.gz  -C /root
cd nrpe-2.12/

yum -y install openssl-devel.x86_64
./configure 
make all




make install-plugin
make install-daemon
make install-daemon-config
make install-xinetd

sed -i 's/only_form=.*/only_from       = 127.0.0.1 172.25.16.10' /etc/xinetd.d/nrpe
echo 'nrpe            5666/tcp                # nrpe' >> /etc/services
