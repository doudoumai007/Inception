#!/bin/bash

set -e

echo "========== WordPress setup =========="

MYSQL_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)


# 创建WordPress要用的工作目录(这也是后面会挂载成volume、给NGINX共享读取的目录)
mkdir -p /var/www/html
cd /var/www/html

# 1. 下载WordPress核心文件(幂等,只在没下载过时执行)
if [ ! -f wp-load.php ]; then
    echo "Downloading WordPress..."

    curl -O https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz

    # 解压出来的文件会在一个叫wordpress/的子文件夹里
    # 这里把里面所有内容(-a保留权限、属性等完整复制)拷贝到当前目录(也就是/var/www/html本身)
    # 原来的子文件夹和下载的压缩包删掉,不留垃圾
    cp -a wordpress/. .
    rm -rf wordpress latest.tar.gz
fi

# 把这个文件/目录的所有者改成 www-data:www-data
chown -R www-data:www-data /var/www/html

# 2. 等待MariaDB容器就绪,再继续往下走
echo "Waiting for Mariadb to be ready..."
ready=false
# 每次尝试用mariadb -e "SELECT 1"去连一下(执行一条最简单的SQLSELECT 1,纯粹是为了测试"能不能连上、连上后能不能执行东西")
# >/dev/null 2>&1:把这条测试命令的输出和报错信息都丢弃,不打印在日志里
for i in $(seq 1 30); do
    if mariadb -h "${MYSQL_HOST}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; then
        echo "MariaDB is ready."
        ready=true
        break
    fi
    sleep 1
done


if [ "$ready" = false ]; then
    echo "Mariadb not reachable after waiting" >&2
    exit 1
fi

# wp-config.php规定 数据库在哪个主机(MYSQL_HOST,也就是mariadb_test这个容器名)、用哪个数据库账号(wpuser)、密码是什么
if [ ! -f wp-config.php ]; then
    echo "Creating wp-config.php..."
    sudo -u www-data wp config create \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="${MYSQL_HOST}" \
        --path=/var/www/html

    echo "Installing WordPress..."
    sudo -u www-data wp core install \
        --url="${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --path=/var/www/html
    
    # comments setting: users must be registered and logged in to comment
    sudo -u www-data wp option update comment_registration 1 --path=/var/www/html

else
    echo "WordPress already configured, skipping config/install."
fi


if  ! sudo -u www-data wp user get "${WP_USER_NAME}" --path=/var/www/html >/dev/null 2>&1; then
    echo "Creating regular user..."
    sudo -u www-data wp user create \
    "${WP_USER_NAME}" "${WP_USER_EMAIL}" \
    --user_pass="${WP_USER_PASSWORD}" \
    --role=author \
    --path=/var/www/html
else
    echo "Regular user already exists, skipping."
fi

chown -R www-data:www-data /var/www/html

echo "Starting PHP-FPM..."

# -F 是"foreground"(前台运行,不要daemonize成后台进程)
mkdir -p /run/php
exec php-fpm8.2  -F

# WordPress 是一个"建站程序"——你不需要自己从零写代码(HTML、CSS、后端逻辑全都自己写)
# 而是装好WordPress之后,它已经帮你把一个网站需要的东西都搭好了:
# 文章发布系统、用户管理、评论功能、主题(网站外观)、插件(功能扩展)……
# 你只需要通过一个网页后台,点点点就能管理网站内容,不需要懂编程
# PHP是一种专门用来写"网站后端"的编程语言(全称"PHP: Hypertext Preprocessor")
# 当你访问一个网站,浏览器发请求过去,如果这个网站是用PHP写的,服务器上的PHP程序就会执行相应的代码
# 比如去数据库里查文章内容、拼装成一个HTML网页——然后把生成好的网页发回给你的浏览器
# WordPress就是一个用PHP写的网站程序(全世界最流行的建站系统之一)
# 所以你的WordPress容器需要装php-fpm,才能真正"运行"WordPress这些PHP代码,把网站内容生成出来
# php-fpm(FastCGI Process Manager)就是专门负责"接收请求→跑PHP代码→返回结果"这个流程的服务进程
# 平时不直接面向用户,而是等着NGINX把用户的请求转发进来。