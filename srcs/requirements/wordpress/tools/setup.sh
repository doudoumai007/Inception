#!/bin/bash

set -e

echo "========== WordPress setup =========="

MYSQL_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)


# working directory for WordPress(mount volume、share with NGINX)
mkdir -p /var/www/html
cd /var/www/html

# 1. download wordPress core documents
if [ ! -f wp-load.php ]; then
    echo "Downloading WordPress..."

    curl -O https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz

    # copy the wordpress directory to curent directory
    cp -a wordpress/. .
    rm -rf wordpress latest.tar.gz
fi

# Change owner for the directory www-data:www-data
chown -R www-data:www-data /var/www/html

# 2. Waiting for Mariadb to be ready
echo "Waiting for Mariadb to be ready..."
ready=false
# Try simple test with mariadb -e "SELECT 1" to see if mariadb can be connect
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

# wp-config.php specifies database hots -> mariadb container
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

# -F run foreground
mkdir -p /run/php
exec php-fpm8.2  -F