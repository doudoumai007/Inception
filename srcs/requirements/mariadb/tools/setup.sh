#!/bin/bash

#
set -e

echo "========== MariaDB setup =========="

# /run dirctory during runtime
MYSQL_PASSWORD=$(cat /run/secrets/db_password)
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

echo "DATABASE=$MYSQL_DATABASE"
echo "USER=$MYSQL_USER"

# mysqld: daemon for MariaDB (MariaDB server)
mkdir -p /run/mysqld

# change owner for mysql:mysql (owner:group)
# -R recursive
chown -R mysql:mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql

# /var/lib/mysql/ mysql system database directory (metadate：user permissions, system configuration)
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB data directory..."

    # > /dev/null: discards the command’s normal output
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null

    # run the temperate program in the background
    # skip setting network
    # store the process in pid (better control, close it later)
    mysqld --user=mysql --skip-networking &
    pid="$!"

    # wating mariadb to be install
    # test if mariadb can connect the server as client and exe SQL
    for i in $(seq 1 30); do
        if mariadb -e "SELECT 1" >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    # Timeout protection
    # test last time
    if ! mariadb -e "SELECT 1" >/dev/null 2>&1; then
        echo "MariaDB failed to start during init" >&2
        exit 1
    fi

    # heredoc stdin put in mariadb from here to EOF
    mariadb <<EOF

    CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};

    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';

    GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';

    ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

    DELETE FROM mysql.user WHERE User='';

    DROP DATABASE IF EXISTS test;

    FLUSH PRIVILEGES;
EOF

    # use mysqladmin to shutdown mysql server
    mysqladmin --user=root --password="${MYSQL_ROOT_PASSWORD}" shutdown

    # wait the process end
    # || true avoid set -e ending the script
    wait "$pid" 2>/dev/null || true
    echo "Initialization cmoplete."
else
    echo "MariaDB data directory already exists, skipping initialization."
fi

echo "Starting MariaDB..."
exec mysqld --user=mysql --bind-address=0.0.0.0