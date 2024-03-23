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
    confirm=${confirm,,} # Convert to lowercase
    if [[ $confirm == "y" || $confirm == "yes" ]]; then
        info "Continuing..."
    elif [[ $confirm,, == "n" || $confirm == "no" ]]; then
        info "Exiting..."
        exit 1
    else
        warn "Invalid response. Exiting..."
        exit 1
    fi
}


function choose_webserver() {
    PS3="Select the web server you want to use: "
    options=("Nginx" "Apache" "Quit")
    select opt in "${options[@]}"; do
        case $opt in
            "Nginx")
                WEB_SERVER="nginx"
                break
                ;;
            "Apache")
                WEB_SERVER="apache"
                break
                ;;
            "Quit")
                info "Exiting..."
                exit 0
                ;;
            *) warn "Invalid option $REPLY" ;;
        esac
    done
}

function install_packages() {
    info "Installing packages..."
    sleep 1
    apt update
    apt install --yes --no-install-recommends \
        bzip2 \
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

    if [ "$WEB_SERVER" == "nginx" ]; then
        apt install --yes --no-install-recommends nginx
        systemctl enable nginx
    elif [ "$WEB_SERVER" == "apache" ]; then
        apt install --yes --no-install-recommends apache2
        systemctl enable apache2
    fi

    systemctl enable mariadb
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

function configure_nginx() {
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

    # Restart Nginx
    systemctl restart nginx
}

function configure_apache() {
# Setup vhost
cat > /etc/apache2/sites-available/000-default.conf << EOF
<VirtualHost *:80>
       DocumentRoot /var/www/html/glpi/public  
       <Directory /var/www/html/glpi/public>
                Require all granted
                RewriteEngine On
                RewriteCond %{REQUEST_FILENAME} !-f
                RewriteRule ^(.*)$ index.php [QSA,L]
        </Directory>
        
        LogLevel warn
        ErrorLog \${APACHE_LOG_DIR}/error-glpi.log
        CustomLog \${APACHE_LOG_DIR}/access-glpi.log combined
        
</VirtualHost>
EOF

    #Disable Apache Web Server Signature
    echo "ServerSignature Off" >> /etc/apache2/apache2.conf
    echo "ServerTokens Prod" >> /etc/apache2/apache2.conf

    #Activation du module rewrite d'apache
    apt install --yes --no-install-recommends php libapache2-mod-php && a2enmod rewrite && systemctl restart apache2

}

function install_glpi()
{
info "Downloading and installing GLPI 10.0.14"
# Get download link for the latest release
DOWNLOADLINK=https://github.com/glpi-project/glpi/releases/download/10.0.14/glpi-10.0.14.tgz
wget -O /tmp/glpi-latest.tgz $DOWNLOADLINK
tar xzf /tmp/glpi-latest.tgz -C /var/www/html/

info "Downloading and installing glpi-inventory-plugin 1.3.5"
FUSIONLINK=https://github.com/glpi-project/glpi-inventory-plugin/releases/download/1.3.5/glpi-glpiinventory-1.3.5.tar.bz2
wget -O /tmp/glpiinventory.tgz $FUSIONLINK
tar xf /tmp/glpiinventory.tgz -C /var/www/html/glpi/plugins

    if [ "$WEB_SERVER" == "nginx" ]; then
        configure_nginx
    elif [ "$WEB_SERVER" == "apache" ]; then
        configure_apache
    fi

# Setup Cron task
echo "*/1 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" >> /etc/cron.d/glpi

}

function secure_php_sessions() {
    if [ "$WEB_SERVER" == "nginx" ]; then
        # For Nginx, modify the FPM configuration
        sed -i 's/^\s*;\?\s*session\.cookie_httponly\s*=/session.cookie_httponly = On/' /etc/php/8.1/fpm/php.ini &&
        systemctl restart php8.1-fpm
    elif [ "$WEB_SERVER" == "apache" ]; then
        # For Apache, modify the Apache2 PHP configuration
        sed -i 's/^\s*;\?\s*session\.cookie_httponly\s*=/session.cookie_httponly = On/' /etc/php/8.1/apache2/php.ini &&
        systemctl restart apache2
    fi
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
choose_webserver
install_packages
mariadb_configure
install_glpi
secure_php_sessions
setup_db
display_credentials

# Add permissions
sudo chown -R www-data:www-data /var/www/html/glpi
sudo chmod -R 775 /var/www/html/glpi
