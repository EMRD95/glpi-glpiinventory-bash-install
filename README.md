# glpi-glpiinventory-bash-install
bash script to install the latest (03/21/2024) Glpi with Glpi Inventory with nginx server

## Usage

```bash
git clone https://github.com/EMRD95/glpi-glpiinventory-bash-install &&

cd glpi* &&

sudo bash glpi.sh
```

Tested on Ubuntu 22.04 Desktop and Server

## Might require setting permissions after running the script

sudo chown -R www-data:www-data /var/www/html/glpi

sudo chmod -R 775 /var/www/html/glpi

## To remove some warnings (script normally apply this)

```bash
    sudo sed -i 's/^\s*;\?\s*session\.cookie_httponly\s*=/session.cookie_httponly = On/' /etc/php/8.1/fpm/php.ini &&
    sudo sed -i 's/^\s*;\?\s*session\.cookie_secure\s*=/session.cookie_secure = On/' /etc/php/8.1/fpm/php.ini &&
    sudo systemctl restart php8.1-fpm
```

#### Or

```bash
sudo nano /etc/php/8.1/fpm/php.ini
```
```bash
session.cookie_secure = On
```
```bash
session.cookie_httponly = On
```
```bash
sudo systemctl restart php8.1-fpm
```
