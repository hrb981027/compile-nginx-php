#!/bin/bash

base_path="~"
nginx_version="1.19.0"
php_version="7.3.18"
user="maikeos"
group="maikeos"
passwd="123456"

cd ${base_path}

rm -rf nginx-${nginx_version}.tar.gz nginx-${nginx_version} php-${php_version}.tar.gz php-${php_version}

wget "https://nginx.org/download/nginx-${nginx_version}.tar.gz"
wget "https://www.php.net/distributions/php-${php_version}.tar.gz"

tar zxf nginx-${nginx_version}.tar.gz
tar zxf php-${php_version}.tar.gz

sudo apt-get install -y libpcre3-dev libssl-dev zlib1g-dev

nginx_path=/usr/local/nginx-${nginx_version}

cd ${base_path}/nginx-${nginx_version}
./configure --prefix=${nginx_path} \
    --sbin-path=${nginx_path}/sbin/nginx \
    --conf-path=${nginx_path}/nginx.conf \
    --error-log-path=${nginx_path}/var/log/error.log \
    --http-log-path=${nginx_path}/var/log/access.log \
    --pid-path=${nginx_path}/var/run/nginx.pid \
    --lock-path=${nginx_path}/var/run/nginx.lock \
    --http-client-body-temp-path=${nginx_path}/var/cache/client_temp \
    --http-proxy-temp-path=${nginx_path}/var/cache/proxy_temp \
    --http-fastcgi-temp-path=${nginx_path}/var/cache/fastcgi_temp \
    --http-uwsgi-temp-path=${nginx_path}/var/cache/uwsgi_temp \
    --http-scgi-temp-path=${nginx_path}/var/cache/scgi_temp \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_stub_status_module \
    --with-http_auth_request_module \
    --with-threads --with-stream \
    --with-stream_ssl_module \
    --with-http_slice_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-file-aio \
    --with-http_v2_module
make && sudo make install

sudo groupadd ${group}
sudo useradd -g ${group} -d /home/${user} -s /bin/bash -m ${user}
sudo bash -c "echo ${user}:${passwd} | chpasswd"

sudo mkdir -p ${nginx_path}/conf.d ${nginx_path}/var/cache
sudo mkdir -p /var/www/html && sudo chown ${user}:${group} /var/www/html

sudo bash -c "cat > ${nginx_path}/nginx.conf" <<EOF
user ${user};
worker_processes auto;

error_log  var/log/error.log;

pid        var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    server_tokens off;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  var/log/access.log  main;

    client_max_body_size 1024M;

    sendfile        on;

    keepalive_timeout  65;

    gzip on;
    gzip_min_length 1k;
    gzip_comp_level 1;
    gzip_types text/plain application/javascript application/x-javascript text/css application/xml text/javascript;
    gzip_static on;
    gzip_vary on;
    gzip_buffers 2 4k;
    gzip_http_version 1.1;

    include conf.d/*.conf;
}
EOF

sudo bash -c "cat > ${nginx_path}/conf.d/default.conf" <<EOF
server {
    listen 80;
    index index.html index.php;
    root /var/www/html;

    location / {
        
    }

    location ~ \.php$ {
        fastcgi_pass   unix:/dev/shm/php-fpm-${php_version}.sock;
        fastcgi_index  index.php;
        include        fastcgi_params;
        fastcgi_param  PATH_INFO \$fastcgi_path_info;
        fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
    }
}
EOF

sudo bash -c "cat > /var/www/html/index.php" <<EOF
<?php
    phpinfo();
EOF

sudo apt-get install -y libxml2-dev libcurl4-openssl-dev libjpeg-dev libpng-dev libfreetype6-dev libzip-dev

php_path=/usr/local/php-${php_version}

cd ${base_path}/php-${php_version}
./configure  prefix=${php_path} \
    --exec-prefix=${php_path} \
    --bindir=${php_path}/bin \
    --sbindir=${php_path}/sbin \
    --includedir=${php_path}/include \
    --libdir=${php_path}/lib/php \
    --mandir=${php_path}/php/man \
    --with-config-file-path=${php_path}/etc \
    --with-mhash --with-openssl \
    --with-mysqli=shared,mysqlnd \
    --with-pdo-mysql=shared,mysqlnd \
    --with-gd \
    --with-iconv \
    --with-zlib \
    --with-libzip \
    --enable-zip \
    --enable-inline-optimization \
    --disable-debug \
    --disable-rpath \
    --enable-shared \
    --enable-xml \
    --enable-bcmath \
    --enable-shmop \
    --enable-sysvsem \
    --enable-sysvshm \
    --enable-sysvmsg \
    --enable-mbregex \
    --enable-mbstring \
    --enable-ftp \
    --enable-pcntl \
    --enable-sockets \
    --with-xmlrpc \
    --enable-soap \
    --without-pear \
    --with-gettext \
    --enable-session \
    --with-curl \
    --with-jpeg-dir \
    --with-freetype-dir \
    --enable-opcache \
    --enable-fpm \
    --disable-cgi \
    --with-fpm-user=www-data \
    --with-fpm-group=www-data \
    --without-gdbm \
    --enable-fast-install \
    --enable-fileinfo
make && sudo make install

sudo cp ~/php-${php_version}/php.ini-production ${php_path}/etc/php.ini
sudo cp ${php_path}/etc/php-fpm.conf.default ${php_path}/etc/php-fpm.conf
sudo cp ${php_path}/etc/php-fpm.d/www.conf.default ${php_path}/etc/php-fpm.d/www.conf

sudo bash -c "cat >> ${php_path}/etc/php.ini" <<EOF
extension=pdo_mysql.so
EOF

sudo sed -i -e "s/user = www-data/user = ${user}/g" ${php_path}/etc/php-fpm.d/www.conf
sudo sed -i -e "s/group = www-data/user = ${group}/g" ${php_path}/etc/php-fpm.d/www.conf

sudo sed -i -e "s/listen = 127.0.0.1:9000/; listen = 127.0.0.1:9000/g" ${php_path}/etc/php-fpm.d/www.conf
sudo bash -c "cat >> ${php_path}/etc/php-fpm.d/www.conf" <<EOF
listen = /dev/shm/php-fpm-${php_version}.sock
listen.mode = 0666
EOF

sudo ${nginx_path}/sbin/nginx && sudo ${php_path}/sbin/php-fpm
