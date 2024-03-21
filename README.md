# glpi-glpiinventory-bash-install
bash script to install the latest (03/21/2024) Glpi with Glpi Inventory with nginx server

Tested on Ubuntu 22.04 Desktop and Server

## Might require setting permissions after running the script

sudo chown -R www-data:www-data /var/www/html/glpi

sudo chmod -R 775 /var/www/html/glpi

## To remove some warnings

sudo nano /etc/php/8.1/fpm/php.ini

session.cookie_secure = On

session.cookie_httponly = On

sudo systemctl restart php8.1-fpm
