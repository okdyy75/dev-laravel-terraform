#!/bin/bash
export HOME="/root"
hostnamectl set-hostname "y-oka-web${count_index}"
yum -y update
yum install -y git
### CloudWatch Logs ##################################################
sudo yum install -y awslogs
cat <<EOT > /etc/awslogs/awscli.conf
[plugins]
cwlogs = cwlogs
[default]
region = ap-northeast-1
EOT
cat <<EOT > /etc/awslogs/awslogs.conf
[general]
state_file = /var/lib/awslogs/agent-state

[${web_log_message}]
file = /var/log/messages
log_group_name = ${web_log_message}
log_stream_name = {instance_id}
datetime_format = %b %d %H:%M:%S 

[${web_log_secure}]
file = /var/log/secure
log_group_name = ${web_log_secure}
log_stream_name = {instance_id}
datetime_format = %b %d %H:%M:%S

[${web_log_nginx_access}]
file = /var/log/nginx/access.log
log_group_name = ${web_log_nginx_access}
log_stream_name = {instance_id}
datetime_format = %d/%b/%Y:%H:%M:%S %z

[${web_log_nginx_error}]
file = /var/log/nginx/error.log
log_group_name = ${web_log_nginx_error}
log_stream_name = {instance_id}
datetime_format = %Y/%m/%d %H:%M:%S

[${web_log_php_fpm_error}]
file = /var/log/php-fpm/error.log
log_group_name = ${web_log_php_fpm_error}
log_stream_name = {instance_id}
datetime_format = %d-%b-%Y %H:%M:%S
EOT
systemctl status awslogsd.service
systemctl enable awslogsd.service
### php-fpm ##################################################
amazon-linux-extras install -y php7.4
yum install -y php-mbstring php-xml
systemctl enable php-fpm.service
sed -i "s|user = apache|user = nginx|" /etc/php-fpm.d/www.conf
sed -i "s|group = apache|group = nginx|" /etc/php-fpm.d/www.conf
systemctl start php-fpm.service
systemctl status php-fpm.service
### nginx ##################################################
amazon-linux-extras install -y nginx1.12
systemctl enable nginx.service
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.org
cat <<'EOT' > /etc/nginx/nginx.conf
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  dev-laravel.okdyy75.ga;
        root         /var/www/dev-laravel/public;
        index index.php index.html index.htm;

        location / {
            try_files $uri $uri/ /index.php$is_args$args;
        }

        location ~ \.php?$ {
            fastcgi_intercept_errors on;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_param PATH_INFO $fastcgi_path_info;
            fastcgi_pass php-fpm;
        }
    }
}
EOT
systemctl start nginx.service
systemctl status nginx.service
### mysql ##################################################
yum install -y https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm
yum-config-manager --disable mysql80-community
yum-config-manager --enable mysql57-community
yum install -y mysql-community-client
### app ##################################################
mkdir -p /var/www
cd /var/www
git clone "https://okdyy75:${github_personal_access_token}@github.com/okdyy75/dev-laravel.git"
cd dev-laravel
mkdir -m 777 vendor
chmod -R 777 bootstrap/cache
chmod -R 777 storage
chown -R nginx:nginx storage/logs
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
composer install
composer dump-autoload
cp -p .env.example .env
php artisan key:generate
sed -i "s|DB_HOST=.*|DB_HOST=${db_host}|" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=${db_name}|" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=${db_username}|" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${db_password}|" .env
sed -i "s|AWS_ACCESS_KEY_ID=.*|AWS_ACCESS_KEY_ID=${aws_access_key_id}|" .env
sed -i "s|AWS_SECRET_ACCESS_KEY=.*|AWS_SECRET_ACCESS_KEY=${aws_secret_access_key}|" .env
sed -i "s|AWS_BUCKET=.*|AWS_BUCKET=${aws_bucket}|" .env
### node.js ##################################################
# curl -sL https://rpm.nodesource.com/setup_10.x | bash -
# yum install -y nodejs
# npm install
# npm run dev
