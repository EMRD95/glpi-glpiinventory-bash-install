# glpi-glpiinventory-bash-install
Bash script to automatically install the latest (03/23/2024) version of [Glpi](https://github.com/glpi-project/glpi/releases) (10.0.14) with [Glpi Inventory plugin](https://github.com/glpi-project/glpi-inventory-plugin/releases) (1.3.5) and Nginx OR Apache web server.

![image](https://github.com/EMRD95/glpi-glpiinventory-bash-install/assets/114953576/825712e7-f64c-4f8b-a807-3957cbdbc57d)

## Usage

```bash
wget https://raw.githubusercontent.com/EMRD95/glpi-glpiinventory-bash-install/main/glpi.sh && sudo bash glpi.sh
```
Or
```bash
curl https://raw.githubusercontent.com/EMRD95/glpi-glpiinventory-bash-install/main/glpi.sh && sudo bash glpi.sh
```
## Start Inventory with [Glpi-agent](https://github.com/glpi-project/glpi-agent/releases)
```bash
wget https://github.com/glpi-project/glpi-agent/releases/download/1.7.1/glpi-agent-1.7.1-linux-installer.pl
 ```
```bash
sudo perl glpi-agent-1.7.1-linux-installer.pl \
    -s http://localhost/plugins/glpiinventory/ \
    --type=all \
    --service \
    --install \
    --runnow
sudo glpi-agent
```
The machine should appear in the inventory instantly.

In case of errors, disable and enable back inventory in webui (Administration > Inventory)

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

