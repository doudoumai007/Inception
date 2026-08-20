FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends \

    nginx \

    # openssl: tool to generate TLS certificate
    openssl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl && \

    # -x509 self-signed TLS certificate
    openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/inception.key \
    -out /etc/nginx/ssl/inception.crt \
    -subj "/C=FR/ST=IDF/L=Paris/O=42/CN=localhost"

# Replace the default config by our config
COPY conf/nginx.config /etc/nginx/sites-available/default

EXPOSE 443

# daemon off: nginx run in foreground
CMD ["nginx", "-g", "daemon off;"]