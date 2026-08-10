#!/bin/bash

#
set -e

echo "========== MariaDB setup =========="

# /run 是Linux系统里专门存放运行时数据的目录
MYSQL_PASSWORD=$(cat /run/secrets/db_password)
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

echo "DATABASE=$MYSQL_DATABASE"
echo "USER=$MYSQL_USER"

# mysqld是MariaDB(以及MySQL)的服务端守护进程(daemon)的名字
mkdir -p /run/mysqld

# 把这个文件/目录的所有者改成 mysql:mysql
# -R recursive 个目录本身,连同它里面所有的子目录、子文件,全部一起递归地改成mysql:mysql所有权
# owner:group
chown -R mysql:mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql

# 如果 /var/lib/mysql/mysql 这个目录不存在,就进入下面的初始化流程
# MariaDB第一次初始化数据目录时,会自动在/var/lib/mysql/下创建一个叫mysql的系统库目录(存放用户权限、系统配置等元数据)
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB data directory..."

    # 真正创建数据库物理文件
    # mariadb-install-db 是MariaDB自带的一个初始化工具,专门负责"从空白状态,
    # 生成数据库运行所需的最基础文件结构"——包括刚提到的系统库mysql(存权限表等)
    # --user=mysql:告诉它用mysql这个用户身份来创建这些文件(权限归属正确)
    # --datadir=/var/lib/mysql:告诉它把这些文件建在哪个目录下
    # > /dev/null:把这个命令的正常输出(一堆初始化过程的提示信息)丢弃掉,不显示在日志里(只是为了让日志更干净,不影响功能)
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null

    # 不监听网络端口(不开3306),只能通过本地socket连接
    # 这是故意的——现在数据库刚"裸装"完,还没设密码、没建业务账号,这时候绝对不能让它对外(尤其是网络)可访问,不然是巨大的安全漏洞(任何人都能无密码连进来)
    # &:让这个命令在后台运行,不阻塞脚本往下执行
    # $! 是bash的一个特殊变量,代表"刚才那条后台命令的进程ID(PID)"
    # 把它存到pid变量里,是为了后面能用这个PID来控制(等待、关闭)这个临时进程。
    mysqld --user=mysql --skip-networking &
    pid="$!"

    # 等待数据库真正就绪
    # mysqld启动是需要一点时间的(要建立各种内部结构),不是命令一执行完它就立刻能接受连接了
    # 循环重试:最多尝试30次(seq 1 30生成1到30的序列,循环30轮),
    # 每次尝试用mariadb -e "SELECT 1"去连一下(执行一条最简单的SQLSELECT 1,纯粹是为了测试"能不能连上、连上后能不能执行东西")
    # >/dev/null 2>&1:把这条测试命令的输出和报错信息都丢弃,不打印在日志里
    for i in $(seq 1 30); do
        if mariadb -e "SELECT 1" >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    # 超时保护
    # 再测试一次 如果确实还是连不上(!取反,"如果不能成功"),就打印一条错误信息到标准错误输出 &2表示stderr
    if ! mariadb -e "SELECT 1" >/dev/null 2>&1; then
        echo "MariaDB failed to start during init" >&2
        exit 1
    fi

    # heredoc 下来若干行,一直到下一个单独一行写着EOF为止,这中间所有的文本内容,都会作为标准输入整体传给mariadb这个命令
    mariadb <<EOF

    CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};

    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';

    GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';

    ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

    DELETE FROM mysql.user WHERE User='';

    DROP DATABASE IF EXISTS test;

    FLUSH PRIVILEGES;
EOF

    # 优雅关闭临时实例
    # mysqladmin 是MariaDB自带的一个管理工具(和mariadb命令行客户端是两个不同的工具
    # ——mariadb是拿来执行SQL查询用的,mysqladmin是拿来做服务器级别的管理操作用的,比如关闭服务器、检查状态等)
    # shutdown 就是它的一个子命令,意思是"优雅地关闭这个数据库服务"
    mysqladmin --user=root --password="${MYSQL_ROOT_PASSWORD}" shutdown

    # 等待进程真正结束
    # wait "$pid":让脚本暂停,一直等到$pid(前面记录的那个后台mysqld进程的PID)这个进程真正彻底退出为止
    # 2>/dev/null:如果wait过程中有什么报错信息(某些边缘情况下可能会有),丢弃不显示
    # || true:如果wait这条命令本身返回了非零(失败)状态
    # 用|| true强制让整体判定为"成功",避免触发脚本开头的set -e导致整个脚本意外终止
    wait "$pid" 2>/dev/null || true
    echo "Initialization cmoplete."
else
    echo "MariaDB data directory already exists, skipping initialization."
fi

echo "Starting MariaDB..."
exec mysqld --user=mysql --bind-address=0.0.0.0