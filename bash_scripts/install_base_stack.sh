#!/bin/bash
# Written by Kevin Petit, ke@vinpet.it
# This script will install the LEMP-stack as we need it.

# Add the PHP ondrej ppa
sudo add-apt-repository ppa:ondrej/php
sudo apt-get update

apt install certbot mariadb-client mariadb-server memcached nginx nginx-common nginx-core zip unzip php7.3 php7.3-bcmath php7.3-cli php7.3-common php7.3-curl php7.3-fpm php7.3-gd php7.3-intl php7.3-json php7.3-ldap php7.3-mbstring php7.3-mysql php7.3-opcache php7.3-readline php7.3-xml php7.3-zip php7.3-memcached vnstat
