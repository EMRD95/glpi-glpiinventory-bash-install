# glpi-glpiinventory-bash-install
Bash script to install the latest (03/23/2024) version of [Glpi](https://github.com/glpi-project/glpi/releases) with [Glpi Inventory plugin](https://github.com/glpi-project/glpi-inventory-plugin/releases) and Nginx OR Apache web server.

## Usage

```bash
wget https://raw.githubusercontent.com/EMRD95/glpi-glpiinventory-bash-install/main/glpi.sh && sudo bash glpi.sh
```
Or
```bash
curl https://raw.githubusercontent.com/EMRD95/glpi-glpiinventory-bash-install/main/glpi.sh && sudo bash glpi.sh
```

Tested on Ubuntu 22.04 Desktop and Server

## Common debugging (for unsupported OSs)

In case of permission issues

```bash
sudo chown -R www-data:www-data /var/www/html/glpi
```
```bash
sudo chmod -R 775 /var/www/html/glpi
```
### To remove the session.cookie_httponly warning (script already apply this)

Nginx
```bash
    sudo sed -i 's/^\s*;\?\s*session\.cookie_httponly\s*=/session.cookie_httponly = On/' /etc/php/8.1/fpm/php.ini &&
    sudo systemctl restart php8.1-fpm
```
Apache
```bash
        sed -i 's/^\s*;\?\s*session\.cookie_httponly\s*=/session.cookie_httponly = On/' /etc/php/8.1/apache2/php.ini &&
        systemctl restart apache2
```
### If you decide to set up HTTPS
Nginx
```bash
    sudo sed -i 's/^\s*;\?\s*session\.cookie_secure\s*=/session.cookie_secure = On/' /etc/php/8.1/fpm/php.ini
```
Apache
```bash
    sudo sed -i 's/^\s*;\?\s*session\.cookie_secure\s*=/session.cookie_secure = On/' /etc/php/8.1/apache2/php.ini
```

Thanks to [https://github.com/jr0w3/glpi-fusioninventory-bash-install](https://github.com/jr0w3/glpi-fusioninventory-bash-install)

