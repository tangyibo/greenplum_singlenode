#!/bin/bash
############################################
# Function :  Greenplum单机一键安装脚本
# Author : tang
# Date : 2020-12-09
#
# Usage: sh install.sh
#
############################################

# RPM包
RPMFILE=files/greenplum-db-6.10.1-rhel7-x86_64.rpm
# 账号密码
PASSWORD=greenplum
# 数据存放目录
DATADIR=/data

# 日志等级
ERROR_MSG="[ERROR] "
INFO_MSG="[INFO] "

# 日志函数
function log() {
    TIME=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$TIME $1"
}

# 环境检查
function check_evnironment() {
    # 要求必须以root账号执行
    if [ "$(whoami)" != 'root' ]; then
    log "$ERROR_MSG You have no permission to run $0 as non-root user."
    exit 1
    fi

    # CentOS7操作系统检查
    v=$(cat /etc/redhat-release | sed -r 's/.* ([0-9]+)\..*/\1/')
    if [ $v -ne 7 ]; then
    log "$ERROR_MSG This program only can run for system CentOS 7 version."
    exit 1
    fi

    # x86_64平台检查
    platform=`uname -m`
    if [ "$platform" != "x86_64" ]; then
    log "$ERROR_MSG This program only can run for x86_64 operation system."
    exit 1
    fi
}

# 利用yum安装依赖包函数
function package_install() {
  log "$INFO_MSG check command package : [ $1 ]"
  if ! rpm -qa | grep -q "^$1"; then
    yum install -y $1
    package_check_ok
  else
    log "$INFO_MSG command [ $1 ] already installed."
  fi
}

# 检查命令是否执行成功
function package_check_ok() {
  ret=$?
  if [ $ret != 0 ]; then
    log "$ERROR_MSG Install failed, error code is $ret, Check the error log."
    exit 1
  fi
}

# 关闭防火墙
function disable_firewall() {
    systemctl stop firewalld && systemctl disable firewalld
    sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config  && setenforce 0
    log "$INFO_MSG Stop and disabled firewall now."
}

# 内核参数修改
function update_kernal_params() {
    # 修改内核/etc/sysctl.conf配置参数
    log "$INFO_MSG Update kernal parameters for /etc/sysctl.conf."
    cat > /etc/sysctl.conf <<EOF
# sysctl settings are defined through files in
# /usr/lib/sysctl.d/, /run/sysctl.d/, and /etc/sysctl.d/.
#
# Vendors settings live in /usr/lib/sysctl.d/.
# To override a whole file, create a new file with the same in
# /etc/sysctl.d/ and put new settings there. To override
# only specific settings, add a file with a lexically later
# name in /etc/sysctl.d/ and put new settings there.
#
# For more information, see sysctl.conf(5) and sysctl.d(5).
kernel.shmmax = 500000000
kernel.shmmni = 4096
kernel.shmall = 4000000000
kernel.sem = 500 1024000 200 4096
kernel.sysrq = 1
kernel.core_uses_pid = 1
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.msgmni = 2048
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.conf.all.arp_filter = 1
net.ipv4.ip_local_port_range = 10000 65535
net.core.netdev_max_backlog = 10000
net.core.rmem_max = 2097152
net.core.wmem_max = 2097152
vm.overcommit_memory = 2
vm.swappiness = 10
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 100
vm.dirty_background_ratio = 0
vm.dirty_ratio=0
vm.dirty_background_bytes = 1610612736
vm.dirty_bytes = 4294967296
EOF
    sysctl -p
    

    # 修改内核/etc/security/limits.conf配置参数
    cat > /etc/security/limits.conf <<EOF
# /etc/security/limits.conf
#
#This file sets the resource limits for the users logged in via PAM.
#It does not affect resource limits of the system services.
#
#Also note that configuration files in /etc/security/limits.d directory,
#which are read in alphabetical order, override the settings in this
#file in case the domain is the same or more specific.
#That means for example that setting a limit for wildcard domain here
#can be overriden with a wildcard setting in a config file in the
#subdirectory, but a user specific setting here can be overriden only
#with a user specific setting in the subdirectory.
#
#Each line describes a limit for a user in the form:
#
#<domain>        <type>  <item>  <value>
#
#Where:
#<domain> can be:
#        - a user name
#        - a group name, with @group syntax
#        - the wildcard *, for default entry
#        - the wildcard %, can be also used with %group syntax,
#                 for maxlogin limit
#
#<type> can have the two values:
#        - "soft" for enforcing the soft limits
#        - "hard" for enforcing hard limits
#
#<item> can be one of the following:
#        - core - limits the core file size (KB)
#        - data - max data size (KB)
#        - fsize - maximum filesize (KB)
#        - memlock - max locked-in-memory address space (KB)
#        - nofile - max number of open file descriptors
#        - rss - max resident set size (KB)
#        - stack - max stack size (KB)
#        - cpu - max CPU time (MIN)
#        - nproc - max number of processes
#        - as - address space limit (KB)
#        - maxlogins - max number of logins for this user
#        - maxsyslogins - max number of logins on the system
#        - priority - the priority to run user process with
#        - locks - max number of file locks the user can hold
#        - sigpending - max number of pending signals
#        - msgqueue - max memory used by POSIX message queues (bytes)
#        - nice - max nice priority allowed to raise to values: [-20, 19]
#        - rtprio - max realtime priority
#
#<domain>      <type>  <item>         <value>
#

#*               soft    core            0
#*               hard    rss             10000
#@student        hard    nproc           20
#@faculty        soft    nproc           20
#@faculty        hard    nproc           50
#ftp             hard    nproc           0
#@student        -       maxlogins       4

# End of file

* soft nofile 65536
* hard nofile 65536
* soft nproc 131072
* hard nproc 131072
EOF
    log "$INFO_MSG Update kernal parameters for /etc/security/limits.conf."
}

function gpdb_install(){
    log "$INFO_MSG Start to install greenplum for single node."

    # 安装依赖包
    package=(epel-release)
    for p in ${package[@]}; do
        package_install $p
    done

    # 创建用户与用户组
    /usr/sbin/groupadd gpadmin
    /usr/sbin/useradd gpadmin -g gpadmin
    usermod -G gpadmin gpadmin
    echo "${PASSWORD}" | passwd --stdin gpadmin
    echo "root:${PASSWORD}" | chpasswd

    # ssh配置
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i -r 's/^.*StrictHostKeyChecking\s+\w+/StrictHostKeyChecking no/' /etc/ssh/ssh_config
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
    systemctl restart sshd

    # 时间同步配置
    (echo "*/5 * * * * /usr/sbin/ntpdate -u cn.pool.ntp.org") | crontab
    systemctl restart crond

    # gpadmin账号的免密配置
    su gpadmin -l -c "ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P \"\""
    su gpadmin -l -c "cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys"
    su gpadmin -l -c "chmod 600 ~/.ssh/authorized_keys" && \
    su gpadmin -l -c "ssh-keyscan -H localhost 2>/dev/null | grep rsa | awk '{print \"localhost \" \$2 \" \" \$3 }' >> ~/.ssh/known_hosts"

    # 安装greenplum的RPM包
    yum install -y $RPMFILE

    # 创建数据库存放目录
    mkdir -p $DATADIR/master
    mkdir -p $DATADIR/primary
    chown -R gpadmin:gpadmin $DATADIR

    # 设置gpadmin账号的环境变量
    su - gpadmin -l -c "echo -e 'source /usr/local/greenplum-db/greenplum_path.sh' >> ~/.bashrc"
    su - gpadmin -l -c "echo -e 'export MASTER_DATA_DIRECTORY=$DATADIR/master/gpseg-1/' >> ~/.bashrc"
    su - gpadmin -l -c "echo -e 'export PGPORT=5432' >> ~/.bashrc"
    su - gpadmin -l -c "echo -e 'export PGUSER=gpadmin' >> ~/.bashrc"
    su - gpadmin -l -c "echo -e 'export PGDATABASE=postgres' >> ~/.bashrc"

    # 初始化集群并修改配置
    rm -f /home/gpadmin/gpinitsystem_config_singlenode
    cat > /home/gpadmin/gpinitsystem_config_singlenode << EOF
ARRAY_NAME="Greenplum Data Platform"
SEG_PREFIX=gpseg
PORT_BASE=6000
declare -a DATA_DIRECTORY=($DATADIR/primary $DATADIR/primary $DATADIR/primary $DATADIR/primary)
MASTER_HOSTNAME=localhost
MASTER_DIRECTORY=$DATADIR/master
MASTER_PORT=5432
TRUSTED_SHELL=ssh
CHECK_POINT_SEGMENTS=8
ENCODING=UNICODE
EOF
cat > /home/gpadmin/gp_hosts_list << EOF
localhost
EOF
cat > /home/gpadmin/initdb_gpdb.sql << EOF
ALTER ROLE "gpadmin" WITH PASSWORD '$PASSWORD';
EOF
    chown -R gpadmin:gpadmin /home/gpadmin
    su - gpadmin -l -c "source ~/.bashrc;gpinitsystem -a --ignore-warnings -c /home/gpadmin/gpinitsystem_config_singlenode -h /home/gpadmin/gp_hosts_list"
    su - gpadmin -l -c "source ~/.bashrc;psql -d postgres -U gpadmin -f /home/gpadmin/initdb_gpdb.sql"
    su - gpadmin -l -c "source ~/.bashrc;gpconfig -c log_statement -v none"
    su - gpadmin -l -c "source ~/.bashrc;gpconfig -c gp_enable_global_deadlock_detector -v on"
    su - gpadmin -l -c "echo \"host  all  all  0.0.0.0/0  password\" >> $DATADIR/master/gpseg-1/pg_hba.conf"
    su - gpadmin -l -c "source ~/.bashrc && sleep 5s && gpstop -u"

    log "$INFO_MSG Install single node Greenplum cluster success!"
}

function gpdb_uninstall(){
    log "$INFO_MSG Start to uninstall greenplum for single node."

    # 杀掉所有进程
    pkill -u gpadmin >/dev/null 2>&1
    log "$INFO_MSG Kill all postgres process!"

    # 删除临时文件
    rm -rf /tmp/.s.PGSQL.* >/dev/null 2>&1
    log "$INFO_MSG erase directory tempariry files of /tmp/.s.PGSQL!"

    # 删除RPM包
    rpm -e greenplum-db-6 >/dev/null 2>&1
    rm -rf /usr/local/greenplum-db-* >/dev/null 2>&1
    log "$INFO_MSG Uninstall RPM package!"

    # 删除账号
    log "$INFO_MSG delete user and group!"
    userdel gpadmin >/dev/null 2>&1
    rm -rf /home/gpadmin
    
    log "$INFO_MSG delete data directory $DATADIR !"
    if [ $DATADIR != "/" ]; then
        rm -rf $DATADIR/*
    fi
    
    log "$INFO_MSG Uninstall single node Greenplum cluster success!"
}

# 安装操作
function install_all(){
    check_evnironment
    disable_firewall
    update_kernal_params
    gpdb_install
}

# 卸载操作
function uninstall_all(){
    gpdb_uninstall
}

function usage(){
    echo "Usage"
    echo "$0 [-h] [-v] [-i] [-e]"
    exit 1
}

function version(){
    echo "version 1.0.20201209"
    exit 1
}

# 判断参数个数
if [ $# != 1 ] ; then
    usage
fi

while getopts ":hvie" opt
do
    case $opt in
        h)
            usage;;
        v)
            version;;
        i)
            install_all;;
        e)
            uninstall_all;;
        ?)
            usage
            exit 1;;
    esac
done