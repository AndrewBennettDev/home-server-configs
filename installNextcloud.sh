#!/bin/bash

###
### IMPORTANT NOTE:
### 
### If this comment is still here this script is experimental and SHOULD NOT BE USED.
### Once I have confirmed that everything works as expected and I have completed multiple
### successful builds on multiple machines I will remove this disclaimer.
###

# Exit immediately if a command exits with a non-zero status
set -e

# Prompt user for database password
read -sp "Enter a password for the Nextcloud database user: " DB_PASSWORD
echo

# Prompt user for domain or IP address
read -p "Enter your domain name or Raspberry Pi IP address: " DOMAIN_NAME

# Update and upgrade the system
sudo apt update && sudo apt upgrade -y

# Install Apache2
sudo apt install apache2 -y

# Install PHP and required extensions
sudo apt install -y php8.2 php8.2-gd php8.2-mysql php8.2-curl php8.2-xml php8.2-zip php8.2-mbstring php8.2-intl php8.2-bcmath php8.2-gmp

# Install MariaDB (MySQL)
sudo apt install mariadb-server -y

# Secure MariaDB installation
sudo mysql_secure_installation <<EOF

y
n
y
y
EOF

# Create Nextcloud database and user
sudo mysql -u root -e "CREATE DATABASE nextcloud;"
sudo mysql -u root -e "CREATE USER 'nextclouduser'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextclouduser'@'localhost';"
sudo mysql -u root -e "FLUSH PRIVILEGES;"

# Download and extract Nextcloud
cd /var/www/
sudo wget https://download.nextcloud.com/server/releases/nextcloud-26.0.0.zip
sudo unzip nextcloud-26.0.0.zip
sudo rm nextcloud-26.0.0.zip
sudo chown -R www-data:www-data /var/www/nextcloud/

# Configure Apache for Nextcloud
sudo bash -c "cat > /etc/apache2/sites-available/nextcloud.conf" <<EOL
<VirtualHost *:80>
    DocumentRoot /var/www/nextcloud/
    ServerName $DOMAIN_NAME

    <Directory /var/www/nextcloud/>
        Require all granted
        AllowOverride All
        Options FollowSymLinks MultiViews
    </Directory>

    <IfModule mod_dav.c>
        Dav off
    </IfModule>

    ErrorLog \${APACHE_LOG_DIR}/nextcloud_error.log
    CustomLog \${APACHE_LOG_DIR}/nextcloud_access.log combined
</VirtualHost>
EOL

# Enable Apache modules and site
sudo a2ensite nextcloud.conf
sudo a2enmod rewrite headers env dir mime
sudo systemctl restart apache2

echo "Nextcloud installation and configuration complete."
echo "Please navigate to http://$DOMAIN_NAME to complete the setup through the web interface."
