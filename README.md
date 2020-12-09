# Greenplum6在CentOS7系统下单节点一键安装

## 一、需求

在单台主机节点上(only one node install)一键安装Greenplum6分布式数据库。

## 二、教程

### 1、制作BIN包

```
git clone https://github.com/tangyibo/greenplum_singlenode.git
cd greenplum_onlyone/
make clean && make build
ls bin/
greenplum6-centos7-singlenode_v1.0.bin

```

## 2、安装

```
sh greenplum6-centos7-singlenode_v1.0.bin -i
```

## 3、卸载

```
sh greenplum6-centos7-singlenode_v1.0.bin -e
```

## 4、参数

| 参数 | 名称 | 取值 | 备注说明 |
| :------| :------ | :------ | :------ |
| Install Path | 软件路径 | /usr/local/greenplum-db | greenplum程序软件安装所在目录，目前无法定制配置 |
| Data Path | 数据路径 | /data | greenplum数据库数据安装所在目录, 该参数可在打包时定制配置 |
| Host Admin User | 管理员账号 | gpadmin | 各个服务器主机上会创建gpadmin账号来启动运行greenplum数据库 |
| Host Admin Password | 管理员密码 | greenplum | 各个服务器主机上gpadmin账号的密码, 该参数可在打包时定制配置|
| GPDB Admin User | GPDB超管账号 | gpadmin | 登录Greenplum数据库的超级管理员账号为gpadmin |
| GPDB Admin Password| GPDB超管密码 | greenplum | 登录Greenplum数据库的超级管理员gpadmin的密码 |

## 5、命令参数

```
[root@localhost bin]# sh greenplum6-centos7-singlenode_v1.0.bin

Usage : greenplum6-centos7-singlenode_v1.0.bin [-h] [-v] [-i] [-e]
         -h       print help information
         -v       print version
         -i       install greenplum
         -e       erase greenplum
```
