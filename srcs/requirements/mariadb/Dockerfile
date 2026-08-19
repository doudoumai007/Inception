FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y mariadb-server && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/lib/mysql/*

# COPY: copy files from the host machine into the image during the build process
COPY tools/setup.sh /setup.sh

RUN chmod +x /setup.sh

EXPOSE 3306

# exe the script when starting the container
ENTRYPOINT ["/setup.sh"]