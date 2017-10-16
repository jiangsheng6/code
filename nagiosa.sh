#!/bin/bash
#servera部署nagios
#安装nagios（rpm包）
cd 
lftp 172.25.254.250:/notes/project/UP200/UP200_nagios-master> mirror pkg/
cd pkg/
yum localinstall *.rpm



#设置密码
htpasswd -c /etc/nagios/passwd nagiosadmin
uplooking
uplooking
cat /etc/nagios/passwd 



systemctl restart httpd
systemctl start nagios


#访问:
#  http://172.25.16.10/nagios/
