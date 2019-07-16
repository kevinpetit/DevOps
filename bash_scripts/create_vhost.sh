#!/bin/bash
# @author: Kevin Petit
# Created 01/12/2018, updated 16/07/2019.
# Based on the script by Seb Dangerfield. Well, somewhat. It does no longer resemble that one much.

# In the original version, config was stored in this file. In this version, we're going to put it in a seperate file in the config file, so we can re-use things.
# Change things in the config dir.
. /root/scripts/config/base.config

# To be sure, create the /srv/www folder if it doesn't exist.
mkdir -p /srv/www

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

# This bit needs reworking. Not blocking now, though.
# # First step after that, test if the user exists.
# until [[ id $USER -eq 1 ]]; do
#       # Our user name was invalid, retry.
#       read -p "That user already exists - every vhost needs it's own unique user! Enter a new username: " USER
# done
# Add the user and pass through the correct home folder, it will auto-create it.
adduser $USER --home /srv/www/$DOMAIN --disabled-password --gecos "" --quiet
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

# Ask if we need to create the A-records at CloudFlare.
# Future improvement.

read -p "Do you want to use Let's Encrypt on this site, or not? If you want to use a wildcard, choose w. [y/w/n] " LETSENCRYPT
# We can only request a wildcard, for now. Other Let's Encrypt stuff will happen below.
if [ $LETSENCRYPT == "w" ]; then
        # Ask if another wildcard is to be used, or if we have to request a new one.
        read -p "Do you want to request a new wildcard (y), or re-use an existing one? [y/n]" LETSENCRYPT_NEW
        if [ $LETSENCRYPT_NEW == "y" ]; then
                # Request a new wildcard certificate.
                /usr/local/bin/certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/scripts/config/cloudflare.config -d *.$DOMAIN --preferred-challenges dns-01
                                                                                                                                                                                                                                            61,1          27%
#       read -p "That user already exists - every vhost needs it's own unique user! Enter a new username: " USER
# done

# Add the user and pass through the correct home folder, it will auto-create it.
adduser $USER --home /srv/www/$DOMAIN --disabled-password --gecos "" --quiet
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

# Ask if we need to create the A-records at CloudFlare.
# Future improvement.

read -p "Do you want to use Let's Encrypt on this site, or not? If you want to use a wildcard, choose w. [y/w/n] " LETSENCRYPT
# We can only request a wildcard, for now. Other Let's Encrypt stuff will happen below.
if [ $LETSENCRYPT == "w" ]; then
        # Ask if another wildcard is to be used, or if we have to request a new one.
        read -p "Do you want to request a new wildcard (y), or re-use an existing one? [y/n]" LETSENCRYPT_NEW
        if [ $LETSENCRYPT_NEW == "y" ]; then
                # Request a new wildcard certificate.
                /usr/local/bin/certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/scripts/config/cloudflare.config -d *.$DOMAIN --preferred-challenges dns-01
                                                                                                                                                                                                                                            61,1          26%
    sed -i "s/@@MAX_CHILDS@@/$MAX_CHILDS/g" $PHP_POOL_CONFIG
    # PHP FPM socket
    sed -i "s#@@SOCKET@@#/var/run/php$PHP_VERSION-fpm-"$USER".sock#g" $NGINX_CONFIG_FILE
    # Restart PHP-FPM
    systemctl restart php$PHP_VERSION-fpm
    # Sessions dir
    mkdir /srv/www/$DOMAIN/sessions
    chmod 700 /srv/www/$DOMAIN/sessions
fi

 # This bit needs to be configured for both the static as PHP version:
sed -i "s/@@HOSTNAME@@/$DOMAIN/g" $NGINX_CONFIG_FILE
sed -i "s/@@PATH@@/\/srv\/www\/$DOMAIN\/$WEBROOT_DIR/g" $NGINX_CONFIG_FILE
sed -i "s/@@LOG_PATH@@/\/srv\/www\/$DOMAIN\/logs/g" $NGINX_CONFIG_FILE

# Set the correct permissions
usermod -aG $USER $NGINX_SERVER_GROUP
chmod g+rx /srv/www/$DOMAIN
chmod 600 $NGINX_CONFIG_FILE
mkdir -p /srv/www/$DOMAIN/$WEBROOT_DIR
mkdir /srv/www/$DOMAIN/logs
chmod 750 /srv/www/$DOMAIN -R
chmod 770 /srv/www/$DOMAIN/logs
chmod 750 /srv/www/$DOMAIN/$WEBROOT_DIR
chown $USER:$USER /srv/www/$DOMAIN/ -R

# Activate the vhost.
ln -s $NGINX_CONFIG_FILE $NGINX_SITES_ENABLED/$DOMAIN.conf

# Start up Nginx.
systemctl restart nginx


# Now is the final bit to get the last of Let's Encrypt to work.
# Nginx is running, site will resolve. So we can now request the certificates, if need be.
if [ $LETSENCRYPT == "y" ]; then
        # Request the certificate.
        certbot certonly -d $DOMAIN -d www.$DOMAIN --keep-until-expiring --agree-tos -m ke@vinpet.it --webroot -w /srv/www/$DOMAIN/$WEBROOT_DIR
        # Should be okay, so now we can modify the config.
        sed -i "s/@@LEENCRYPT@@/$DOMAIN/g" $NGINX_CONFIG_FILE
fi
if [ $LETSENCRYPT == "REUSE" ]
        then
                echo ">> Using an existing wildcard for $LETSENCRYPT_EXISTING_WILDCARD"
                # We want to use an existing wildcard cert. Let's add that to the config.
                sed -i "s/@@LEENCRYPT@@/$LETSENCRYPT_EXISTING_WILDCARD/g" $NGINX_CONFIG_FILE
fi
# Change the Nginx config one last time.
sed -i 's/#####//g' $NGINX_CONFIG_FILE
sed -i 's/listen 80; # For debugging.//g' $NGINX_CONFIG_FILE

# Reload nginx one last time.
systemctl restart nginx

# Give kevinpetit rights on the new folder.
setfacl -R -m u:kevinpetit:rwx /srv/www/$DOMAIN

# That should be all.
echo "We're done here."
