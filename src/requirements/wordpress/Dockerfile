FROM debian:bullseye

# apt 是Debian/Ubuntu系统的包管理器(package manager)——专门用来安装、卸载、更新系统软件的工具
# update:刷新本地的软件包索引列表
# install -y 对安装过程中所有的确认提示,自动回答yes
# 只装真正必需的依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends \

    # SSL证书的合法性
    ca-certificates \

    # PHP的"FastCGI进程管理器"——真正让PHP代码能跑起来、处理网页请求的核心服务
    php7.4-fpm \

    # PHP连接MySQL/MariaDB数据库用的扩展模块——WordPress要读写数据库,必须装这个才能"说得上话"
    php7.4-mysql \

    # PHP里发起网络请求用的扩展(WordPress有些功能,比如检查更新、外部API调用,需要这个)
    php7.4-curl \

    # PHP处理图片用的扩展(比如WordPress自动生成缩略图、裁剪图片时要用)
    php7.4-gd \

    # 处理"多字节字符"用的扩展(比如中文、日文这种一个字符占多个字节的文字,没有这个可能出现乱码或功能异常
    php7.4-mbstring \

    # 处理XML格式数据用的扩展(WordPress导入导出内容、部分插件功能会用到XML)
    php7.4-xml \

    # 处理zip压缩文件用的扩展(WordPress装插件/主题时,经常需要解压zip包)
    php7.4-zip \

    # 命令行下载/网络请求工具(下载wp-cli要用它)
    curl \

    # 数据库的客户端工具(不是数据库服务器本身)
    # 这样WordPress容器里就能用mariadb命令去连接MariaDB容器,方便entrypoint脚本里"等待数据库就绪"这类检测逻辑
    mariadb-client \

    sudo \
    
    # 用rm -rf把apt-get update那一步下载下来的软件包索引清单全部删掉
    && rm -rf /var/lib/apt/lists/*

# .phar 是"PHP Archive"的缩写,你可以把它理解成PHP世界的一个打包好的可执行程序文件(类似于Java的.jar)
# wp-cli 是WordPress官方推出的命令行管理工具——正常你管理WordPress网站(建站、装插件、建用户等)都是打开浏览器点来点去
# 但wp-cli让你可以用命令行一行一行敲命令来完成同样的事
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# 把php-fpm的监听方式,从Unix socket改成TCP的0.0.0.0:9000,
# 这样nginx容器才能通过网络(而不是本地socket)连接到它
RUN sed -i 's|listen = /run/php/php7.4-fpm.sock|listen = 0.0.0.0:9000|' /etc/php/7.4/fpm/pool.d/www.conf

COPY tools/setup.sh /setup.sh

RUN chmod +x /setup.sh

EXPOSE 9000

ENTRYPOINT ["/setup.sh"]
