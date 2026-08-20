FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends \

    ca-certificates \
    php8.2-fpm \
    php8.2-mysql \
    php8.2-curl \
    php8.2-gd \
    php8.2-mbstring \
    php8.2-xml \
    php8.2-zip \
    curl \
    mariadb-client \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# .phar PHP Archive: packed exe for PHP
# wp-cli for entering wordpress comments
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# change listen method from Unix socket to TCP0.0.0.0:9000, so that Nginx can connect from port 9000
RUN sed -i 's|listen = /run/php/php8.2-fpm.sock|listen = 0.0.0.0:9000|' /etc/php/8.2/fpm/pool.d/www.conf

COPY tools/setup.sh /setup.sh

RUN chmod +x /setup.sh

EXPOSE 9000

ENTRYPOINT ["/setup.sh"]
