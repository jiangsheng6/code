#!/bin/bash

#selinux模块
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
setenforce 0

#创建局域网，其他机子从这下载
sed -i 's/ONBOOT=yes/ONBOOT=no/' /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i '$a GATEWAY=192.168.0.10' /etc/sysconfig/network-scripts/ifcfg-eth1

#开机自动关闭防火墙
echo "/sbin/setenforce 0" >> /etc/rc.local

#需要增加执行全限
chmod +x /etc/rc.local

#挂载nfs目录
mount -t nfs 172.25.254.250:/content /mnt/
mkdir /yum

#将光盘挂在到/yum
mount -o loop /mnt/rhel7.1/x86_64/isos/rhel-server-7.1-x86_64-dvd.iso /yum/
cd /etc/yum.repos.d/
find . -regex '.*\.repo$' -exec mv {} {}.back \;
cat > /etc/yum.repos.d/local.repo << EOT
[local]
baseurl=file:///yum
gpgcheck=0
EOT
yum clean all
yum repolist

#搭建DHCP
yum -y install dhcp && echo "dhcp服务安装完毕"
\cp /usr/share/doc/dhcp-4.2.5/dhcpd.conf.example /etc/dhcp/dhcpd.conf
cat > /etc/dhcp/dhcpd.conf << EOT
allow booting;
allow bootp;
option domain-name "pod16.example.com";
option domain-name-servers 172.25.254.254;
default-lease-time 600;
max-lease-time 7200;
log-facility local7;
subnet 192.168.0.0 netmask 255.255.255.0 {
	range 192.168.0.50 192.168.0.60;
	option routers 192.168.0.10;
	option broadcast-address 192.168.0.255;
	next-server 192.168.0.16;
	filename "pxelinux.0";
}
EOT
dhcp -t & > /dev/null && echo "dhcp配置完毕"
systemctl restart dhcpd && echo "成功启动dhcp"
yum -y install tftp-server
yum -y install syslinux
cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
cd /var/lib/tftpboot/
mkdir pxelinux.cfg
cd pxelinux.cfg
touch default
cat > default << EOT
default	vesamenu.c32
timeout 60
display boot.msg
menu background splash.jpg
meni title Welcome to Global Learning Service Setup!
label local
	menu label Boot from ^local drive 
	menu default
	localhost 0xffff
label install7
	menu label Install rhel7
	kernel vmlinuz
	append initrd=initrd.img ks=http://192.168.0.16/myks.cfg
label install6
        menu label Install rhel6u5
        kernel rhel6u5/vmlinuz
        append initrd=rhel6u5/initrd.img ks=http://192.168.0.16/rhel6u5_ks.cfg
EOF
EOT
cd /mnt/rhel7.1/x86_64/dvd/isolinux
cp splash.png vesamenu.c32 vmlinuz initrd.img /var/lib/tftpboot/
sed -i 's/disable.*/        disable                 = no/' /etc/xinetd.d/tftp
systemctl restart xinetd


mkdir /var/www/html
cat >  /var/www/html/myks.cfg << EOT
auth --enableshadow --passalgo=sha512

#Reboot after installation 
reboot # 装完系统之后是否重启

# Use network installation
url --url="http://192.168.0.16/rhel7u1/"  # 网络安装介质所在位置
# Use graphical install
#graphical 
text # 采用字符界面安装
# Firewall configuration
firewall --enabled --service=ssh  # 防火墙的配置
firstboot --disable 
ignoredisk --only-use=vda

# Keyboard layouts
# old format: keyboard us
# new format:
keyboard --vckeymap=us --xlayouts='us' # 键盘的配置
# System language 
lang en_US.UTF-8 # 语言制式的设置

# Network information
network  --bootproto=dhcp # 网络设置
network  --hostname=localhost.localdomain

#repo --name="Server-ResilientStorage" --baseurl=http://download.eng.bos.redhat.com/rel-eng/latest-RHEL-7/compose/Server/x86_64/os//addons/ResilientStorage
# Root password
rootpw --iscrypted nope 

# SELinux configuration
selinux --disabled
# System services
services --disabled="kdump,rhsmcertd" --enabled="network,sshd,rsyslog,ovirt-guest-agent,chronyd"
# System timezone
timezone Asia/Shanghai --isUtc

# System bootloader configuration
bootloader --append="console=tty0 crashkernel=auto" --location=mbr --timeout=1 --boot-drive=vda 
# 设置boot loader安装选项 --append指定内核参数 --location 设定引导记录的位置
# Clear the Master Boot Record
zerombr # 清空MBR
# Partition clearing information
clearpart --all --initlabel # 清空分区信息
# Disk partitioning information
part / --fstype="xfs" --ondisk=vda --size=6144 # 设置根目录的分区情况
%post # 装完系统后执行脚本部分
echo "redhat" | passwd --stdin root
useradd carol
echo "redhat" | passwd --stdin carol
# workaround anaconda requirements
%end

%packages # 需要安装的软件包
@core
%end
EOT

yum -y install httpd
ln -s /yum/ /var/www/html/rhel7u1

service httpd start &>/dev/null
systemctl start httpd
systemctl enable xinetd
systemctl enable httpd
systemctl enable dhcpd

#rhel6

mkdir  /rhel6u5
mount -o loop /mnt/rhel6.5/x86_64/isos/rhel-server-6.5-x86_64-dvd.iso /rhel6u5
ln -s /rhel6u5/ /var/www/html/rhel6u5
service httpd restart
cat >  /var/www/html/rhel6u5_ks.cfg << EOF
#platform=x86, AMD64, or Intel EM64T
#version=DEVEL
# Firewall configuration
firewall --disabled
# Install OS instead of upgrade
install
# Use network installation
url --url="http://192.168.0.16/rhel6u5"
# Root password
rootpw --plaintext redhat
# System authorization information
auth  --useshadow  --passalgo=sha512
# Use text mode install
text
firstboot --disable
# System keyboard
keyboard us
# System language
lang en_US
# SELinux configuration
selinux --disabled
# Installation logging level
logging --level=info
# Reboot after installation
reboot
# System timezone
timezone --isUtc Asia/Shanghai
# Network information
network  --bootproto=dhcp --device=eth0 --onboot=on
# System bootloader configuration
bootloader --location=mbr
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel 
# Disk partitioning information
part /boot --fstype="ext4" --size=200
part / --fstype="ext4" --size=9000
part swap --fstype="swap" --size=1024

%pre
clearpart --all
part /boot --fstype ext4 --size=100
part pv.100000 --size=10000
part swap --size=512
volgroup vg --pesize=32768 pv.100000
logvol /home --fstype ext4 --name=lv_home --vgname=vg --size=480
logvol / --fstype ext4 --name=lv_root --vgname=vg --size=8192
%end


%post
touch /tmp/abc
%end

%packages
@base
@chinese-support
penssh-clients
%end

EOF
mkdir  -p /var/lib/tftpboot/rhel6u5
cd /rhel6u5/isolinux
\cp vmlinuz initrd.img /var/lib/tftpboot/rhel6u5/
