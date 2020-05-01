#!/bin/bash
# @author: Kevin Petit
# Created 01/12/2018, updated 01/05/2020.
# Based on the script by Seb Dangerfield. Well, somewhat. It does no longer resemble that one much.
# Updated to be used with Caddy v2

# Caddy config file location and user.
CADDY_FILE='/etc/caddy/Caddyfile'
CADDY_USER='caddy'
CADDY_GROUP='caddy'

# PHP version you want to use.
PHP_VERSION=7.4
PHP_POOL_CONFIG=

# To be sure, create the /var/www folder if it doesn't exist.
mkdir -p /var/www

# Check if it's a valid domain or not. Very basic validation.
PATTERN="^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$";

# Until the domain validates against the pattern, keep asking for the domain name.
read -p "What is the domain you want to use for this vhost, without www? " DOMAIN
until [[ "$DOMAIN" =~ $PATTERN ]]; do
        # It didn't validate, try again. We will keep trying until this validates.
        read -p "The domain entered is invalid, try again: " DOMAIN
done

# We got through our until, so the domain name is valid, time to go to next step, adding a user
PATTERN="^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$"
read -p "What user would you like to use for this vhost? " USER
until [[ "$USER" =~ $PATTERN ]]; do
        # Our user name was invalid, retry.
        read -p "That user is invalid, could you type in the username for this vhost, it should start with a lowercase and can be max 32 characters long: " USER
done

# Check if this user already exists or not.
until ! id "$USER" >/dev/null 2>&1; do
    # User already exists.
    read -p "Sorry, but this user already exists. For security reasons, every vhost should use it's own user. Please enter a new username: " USER
done

# Add the user and pass through the correct home folder, it will auto-create it.
adduser $USER --home /var/www/$DOMAIN --disabled-password --gecos "" --quiet
if [ $? -ne 0 ]
then
        echo "!! Something went wrong and $USER was not created, abort mission !!"
        exit 1
else
        echo ">> User $USER was created."
fi

# Default webroot, or not?
read -p "Do you want to change the webroot folder? By default it's public_html. " CHANGE_WEBROOT
if [ $CHANGE_WEBROOT == "y" ]; then
        read -p "Enter the webroot folder: " WEBROOT_DIR
else
        WEBROOT_DIR='public_html'
fi

# Is this a static website or a PHP dynamic one? Changes quite a lot in the config and questions we need to ask.
read -p "Is this a static website (non-PHP)? [y/n] " STATIC_SITE
if [ $STATIC_SITE == "n" ]; then
    # Time to generate our PHP-FPM pool configuration.
    PHP_POOL_CONFIG='/etc/php/'$PHP_VERSION'/fpm/pool.d/'$DOMAIN'.pool.conf'
    cp ../templates/php_pool.conf $PHP_POOL_CONFIG
    read -p "What is the minimum amount of PHP-FPM servers for this site? Should be at least 1:" FPM_MIN_SERVERS
    read -p "What is the maximum amount of PHP-FPM servers for this site? Should be at least 1:" FPM_MAX_SERVERS
    read -p "What is the default amount of PHP-FPM servers for this site? Should be at least 1:" FPM_DEF_SERVERS
    # Change the config file
    sed -i "s/@@USER@@/$USER/g" $PHP_POOL_CONFIG
    sed -i "s/@@HOME_DIR@@/\/var\/www\/$DOMAIN/g" $PHP_POOL_CONFIG
    sed -i "s/@@START_SERVERS@@/$FPM_DEF_SERVERS/g" $PHP_POOL_CONFIG
    sed -i "s/@@MIN_SERVERS@@/$FPM_MIN_SERVERS/g" $PHP_POOL_CONFIG
    sed -i "s/@@MAX_SERVERS@@/$FPM_MAX_SERVERS/g" $PHP_POOL_CONFIG
    MAX_CHILDS=$(($FPM_MAX_SERVERS+$FPM_DEF_SERVERS))
    sed -i "s/@@MAX_CHILDS@@/$MAX_CHILDS/g" $PHP_POOL_CONFIG
    # Restart PHP-FPM
    systemctl restart php$PHP_VERSION-fpm
    # Sessions dir
    mkdir /var/www/$DOMAIN/sessions
    chmod 700 /var/www/$DOMAIN/sessions
fi

# Start building our Caddyfile configuration.
# Create a blank line
printf "\n" >> CADDY_FILE
printf "$DOMAIN, www.$DOMAIN {\n" >> $CADDY_FILE
printf "\troot * /var/www/$DOMAIN/$WEBROOT_DIR\n"
printf "\tencode zstd gzip\n" >> $CADDY_FILE
if [ $STATIC_SITE == "y" ]; then
    printf "\tfile_server\n" >> $CADDY_FILE
else
    printf "\tphp_fastcgi unix//run/php/php7.4-fpm-$USER.sock\n" >> $CADDY_FILE
fi
printf "}\n" >> $CADDY_FILE

fi

# Set the correct permissions
usermod -aG $USER $CADDY_GROUP
chmod g+rx /var/www/$DOMAIN
mkdir -p /var/www/$DOMAIN/$WEBROOT_DIR
mkdir /var/www/$DOMAIN/logs
chmod 750 /var/www/$DOMAIN -R
chmod 770 /var/www/$DOMAIN/logs
chmod 750 /var/www/$DOMAIN/$WEBROOT_DIR
chown $USER:$USER /var/www/$DOMAIN/ -R

# Give kevinpetit rights on the new folder.
setfacl -R -m u:kevinpetit:rwx /var/www/$DOMAIN

# That should be all.
echo "We're done here."
