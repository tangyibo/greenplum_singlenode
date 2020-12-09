#!/bin/bash
############################################
# Function :  BIN包启动脚本
# Author : tang
# Date : 2020-12-09
#
############################################
SELF_SHELL_PATH=$(cd `dirname $0`; pwd)
INSTALL_LOG_FILE=${SELF_SHELL_PATH}/install_gpdb.log

# 使用说明
print_usage(){
    echo ""
    echo -e "Usage : $0 [-h] [-v] [-i] [-e]"
    echo -e "\t -h \t  print help information "
    echo -e "\t -v \t  print version"
    echo -e "\t -i \t  install greenplum"
    echo -e "\t -e \t  erase greenplum"
}


# 判断参数个数
if [ $# != 1 ] ; then
    print_usage
fi

# 解压后执行操作
TMP_FILE_NAME=/tmp/greenplum6-centos7-release.tgz
sed -n -e '1,/^exit 0/!p' $0 > ${TMP_FILE_NAME} 2>/dev/null

mkdir -p /tmp/greenplum
tar zxf ${TMP_FILE_NAME} -C /tmp/greenplum
rm -rf ${TMP_FILE_NAME}
cd /tmp/greenplum/src/


while getopts ":hvie" opt
do
    case $opt in
        h)
            print_usage;;
        v)
            sh install.sh -v;;
        i)
            sh install.sh -i | tee -a ${INSTALL_LOG_FILE};;
        e)
            sh install.sh -e | tee -a ${INSTALL_LOG_FILE};;
        ?)
            print_usage
            exit 1;;
    esac
done

rm -rf ${TMP_FILE_NAME}
rm -rf /tmp/greenplum

# 结束返回
echo -e ""  
exit 0
