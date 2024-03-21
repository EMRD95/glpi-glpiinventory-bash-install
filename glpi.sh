#!/bin/bash
#
# GLPI install script

function warn(){
    echo -e '\e[31m'$1'\e[0m';
}
function info(){
    echo -e '\e[36m'$1'\e[0m';
}

function check_root()
{
# Vérification des privilèges root
if [[ "$(id -u)" -ne 0 ]]
then
        warn "This script must be run as root" >&2
  exit 1
else
        info "Root privilege: OK"
fi
}

function check_distro()
{
# Constante pour les versions de Debian acceptables
DEBIAN_VERSIONS=("11")

# Constante pour les versions d'Ubuntu acceptables
UBUNTU_VERSIONS=("22.04")

# Récupération du nom de la distribution
DISTRO=$(lsb_release -is)

# Récupération de la version de la distribution
VERSION=$(lsb_release -rs)

# Vérifie si c'est une distribution Debian
if [ "$DISTRO" == "Debian" ]; then
        # Vérifie si la version de Debian est acceptable
        if [[ " ${DEBIAN_VERSIONS[*]} " == *" $VERSION "* ]]; then
                info "Your operating system version ($DISTRO $VERSION) is compatible."
        else
                warn "Your operating system version ($DISTRO $VERSION) is not noted as compatible."
                warn "Do you still want to force the installation? Be careful, if you choose to force the script, it is at your own risk."
                info "Are you sure you want to continue? [Y/n]"
                read response
                if [ $response == "Y" ]; then
                info "Continuing..."
                elif [ $response == "n" ]; then
                info "Exiting..."
                exit 1
                else
                warn "Invalid response. Exiting..."
                exit 1
                fi
        fi

# Vérifie si c'est une distribution Ubuntu
elif [ "$DISTRO" == "Ubuntu" ]; then
        # Vérifie si la version d'Ubuntu est acceptable
        if [[ " ${UBUNTU_VERSIONS[*]} " == *" $VERSION "* ]]; then
                info "Your operating system version ($DISTRO $VERSION) is compatible."
        else
                warn "Your operating system version ($DISTRO $VERSION) is not noted as compatible."
                warn "Do you still want to force the installation? Be careful, if you choose to force the script, it is at your own risk."
                info "Are you sure you want to continue? [Y/n]"
                read response
                if [ $response == "Y" ]; then
                info "Continuing..."
                elif [ $response == "n" ]; then
                info "Exiting..."
                exit 1
                else
                warn "Invalid response. Exiting..."
                exit 1
                fi
        fi
# Si c'est une autre distribution
else
        warn "Il s'agit d'une autre distribution que Debian ou Ubuntu qui n'est pas compatible."
        exit 1
fi
}

function network_info()
{
INTERFACE=$(ip route | awk 'NR==1 {print $5}')
IPADRESS=$(ip addr show $INTERFACE | grep inet | awk '{ print $2; }' | sed 's/\/.*$//' | head -n 1)
HOST=$(hostname)
}

function confirm_installation()
{
warn "This script will now install the necessary packages for installing and configuring GLPI."
info "Are you sure you want to continue? [Y/n]"
read confirm
if [ $confirm == "Y" ]; then
        info "Continuing..."
elif [ $confirm == "n" ]; then
        info "Exiting..."
        exit 1
else
        warn "Invalid response. Exiting..."
        exit 1
fi
}

function install_packages()
{
info "Installing packages..."
sleep 1
apt update
apt install --yes --no-install-recommends \
nginx \
mariadb-server \
perl \
curl \
jq \
php-fpm
info "Installing php extensions..."
apt install --yes --no-install-recommends \
php-ldap \
php-imap \
php-apcu \
php-xmlrpc \
php-cas \
php-mysqli \
php-mbstring \
php-curl \
php-gd \
php-simplexml \
php-xml \
php-intl \
php-zip \
php-bz2
systemctl enable mariadb
systemctl enable nginx
}

function mariadb_configure()
{
info "Configuring MariaDB..."
sleep 1
SLQROOTPWD=$(openssl rand -base64 48 | cut -c1-12 )
SQLGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
systemctl start mariadb
sleep 1

# Set the root password
mysql -e "UPDATE mysql.user SET Password = PASSWORD('$SLQROOTPWD') WHERE User = 'root'"

# Remove anonymous user accounts
mysql -e "DELETE FROM mysql.user WHERE User = ''"

# Disable remote root login
mysql -e "DELETE FROM mysql.user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"

# Remove the test database
mysql -e "DROP DATABASE test"

# Reload privileges
mysql -e "FLUSH PRIVILEGES"

mysql -u root -p'$SLQROOTPWD' <<EOF
# Create a new database
CREATE DATABASE glpi;
# Create a new user
CREATE USER 'glpi_user'@'localhost' IDENTIFIED BY '$SQLGLPIPWD';
# Grant privileges to the new user for the new database
GRANT ALL PRIVILEGES ON glpi.* TO 'glpi_user'@'localhost';
# Reload privileges
FLUSH PRIVILEGES;
EOF
}

function install_glpi()
{
info "Downloading and installing GLPI 10.0.12"
# Get download link for the latest release
DOWNLOADLINK=https://github.com/glpi-project/glpi/releases/download/10.0.14/glpi-10.0.14.tgz
wget -O /tmp/glpi-latest.tgz $DOWNLOADLINK
tar xzf /tmp/glpi-latest.tgz -C /var/www/html/

info "Downloading and installing glpi-inventory-plugin 1.3.5"
FUSIONLINK=https://github.com/glpi-project/glpi-inventory-plugin/releases/download/1.3.5/glpi-glpiinventory-1.3.5.tar.bz2
wget -O /tmp/glpiinventory.tar.bz2 $FUSIONLINK

# Create the plugin directory if it doesn't exist
mkdir -p /var/www/html/glpi/plugins/glpiinventory

# Extract directly into the correct directory
tar xjf /tmp/glpiinventory.tar.bz2 -C /var/www/html/glpi/plugins/glpiinventory --strip-components 1

# Check the structure to ensure it's correct
ls -l /var/www/html/glpi/plugins/glpiinventory


# Setup server block
cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80;
    listen [::]:80;
    server_name glpi.example.com;

    root /var/www/html/glpi/public;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php\$is_args\$args;
    }

    location ~ ^/index\.php(/|\$) {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_split_path_info ^(.+\.php)(/.*)\$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Setup Cron task
echo "*/1 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" >> /etc/cron.d/glpi

function secure_php_sessions() {
    info "Securing PHP sessions..."
    sed -i 's/;session.cookie_secure =/session.cookie_secure = On/' /etc/php/8.1/fpm/php.ini
    sed -i 's/;session.cookie_httponly =/session.cookie_httponly = On/' /etc/php/8.1/fpm/php.ini
    systemctl restart php8.1-fpm
}

# Restart Nginx
systemctl restart nginx
}

function setup_db()
{
info "Setting up GLPI..."
cd /var/www/html/glpi
php bin/console db:install --db-name=glpi --db-user=glpi_user --db-password=$SQLGLPIPWD --no-interaction
# Sleep 1 because GLPI install latency
sleep 1
info "Installing and activating GlpiInventory plugin"
php bin/console glpi:plugin:install glpiinventory --username=glpi
php bin/console glpi:plugin:activate glpiinventory

rm -rf /var/www/html/glpi/install
}

function display_credentials()
{
info "=======> GLPI installation details  <======="
warn "It is important to record these informations. If you lose them, they will be unrecoverable."
info "==> GLPI:"
info "Default user accounts are:"
info "USER       -  PASSWORD       -  ACCESS"
info "glpi       -  glpi           -  admin account,"
info "tech       -  tech           -  technical account,"
info "normal     -  normal         -  normal account,"
info "post-only  -  postonly       -  post-only account."
echo ""
info "You can connect access GLPI web page from IP or hostname:"
info "http://$IPADRESS or http://$HOST"
echo ""
info "==> Database:"
info "root password:           $SLQROOTPWD"
info "glpi_user password:      $SQLGLPIPWD"
info "GLPI database name:          glpi"
info "<==========================================>"
echo ""
info "If you encounter any issue with this script, please report it on GitHub: https://github.com/jr0w3/GLPI_install_script/issues"
}

check_root
check_distro
confirm_installation
network_info
install_packages
mariadb_configure
install_glpi
setup_db
display_credentials

# Add permissions
sudo chown -R www-data:www-data /var/www/html/glpi
sudo chmod -R 775 /var/www/html/glpi

# Restart Nginx
systemctl restart nginx
