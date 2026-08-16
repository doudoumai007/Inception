FROM debian:bullseye

RUN apt-get update && \
    apt-get install -y mariadb-server && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/lib/mysql/*

# COPY 是Dockerfile里的一个构建指令,作用是把宿主机(build时你的电脑)上的文件,复制进正在构建的镜像里
# 把脚本文件从你的项目目录,打包进镜像
COPY tools/setup.sh /setup.sh
# 给这个脚本加上"可执行"权限
RUN chmod +x /setup.sh

EXPOSE 3306

# 容器启动时,自动去执行这个脚本
ENTRYPOINT ["/setup.sh"]