#!/bin/bash

dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

dnf -y install nginx

systemctl start nginx
systemctl enable nginx

dnf install -y php php-mysqlnd php-fpm php-opcache php-gd php-xml php-mbstring php-json

systemctl start php-fpm
systemctl enable php-fpm

dnf install -y wget git

wget https://getcomposer.org/installer -O composer-installer.php
php composer-installer.php --filename=composer --install-dir=/usr/bin

dnf -y install mariadb-server
systemctl start mariadb
systemctl enable mariadb

mysql_secure_installation
