FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends \

    nginx \

    # openssl:专门用来生成TLS证书的工具
    openssl \
    && rm -rf /var/lib/apt/lists/*

# 生成自签TLS证书(构建阶段就生成,免得每次容器重启都重新生成)
RUN mkdir -p /etc/nginx/ssl && \

    # -x509表示生成一个自签名证书(不是找权威机构签发,因为这只是本地/学校环境测试用)
    # -days 365表示证书有效期一年
    # -newkey rsa:2048表示同时生成一个2048位的RSA私钥
    # -subj "..."是提前把证书里要填的信息(国家、组织、域名等)写死,这样构建过程不会卡住等你手动输入
    openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/inception.key \
    -out /etc/nginx/ssl/inception.crt \
    -subj "/C=FR/ST=IDF/L=Paris/O=42/CN=localhost"

# 把我们自己写的nginx配置,替换掉默认配置
COPY conf/nginx.config /etc/nginx/sites-available/default

EXPOSE 443

# daemon off是告诉NGINX"别在后台默默运行(默认行为),要在前台运行
CMD ["nginx", "-g", "daemon off;"]