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

echo "Welcome to My First Home Lab! Start by choosing the products you want to install..."

read -p "Do you want to use Tailscale (highly recommended)? (y/n): " USE_TAILSCALE
read -p "Do you want to use Jellyfin? (y/n): " USE_JELLYFIN
read -p "Do you want to use Immich? (y/n): " USE_IMMICH
read -p "Do you want to use Nextcloud? (y/n): " USE_NEXTCLOUD
read -p "Do you want to use Home Assistant? (y/n): " USE_HA

##################################################################################################################

# Install Tailscale OR set IP manually
if [[ "$USE_TAILSCALE" =~ ^[Yy]$ ]]; then
    echo "Installing Tailscale, please be prepared to authenticate..."
    curl -fsSL https://tailscale.com/install.sh | sh

    sudo tailscale up

    echo "Waiting for Tailscale to establish a connection..."
    while ! ip addr show tailscale0 &>/dev/null; do
        sleep 1
    done

    DOMAIN_NAME=$(ip addr show tailscale0 | awk '/inet / {print $2}' | cut -d'/' -f1)

    if [[ -z "$DOMAIN_NAME" ]]; then
        echo "Error: Could not retrieve Tailscale IP. Please check if Tailscale is running."
        exit 1
    fi

    echo "Tailscale IP detected: $DOMAIN_NAME"
else
    read -p "Enter your domain name or server IP address: " DOMAIN_NAME
fi

echo "Using domain/IP: $DOMAIN_NAME"

# Move into home directory
cd

###################################################################################################################

# Install Docker (required for most applications)
echo "Installing Docker..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

####################################################################################################################

# Install Jellyfin
if [[ "$USE_JELLYFIN" =~ ^[Yy]$ ]]; then
    echo "Installing Jellyfin..."
    curl https://repo.jellyfin.org/install-debuntu.sh | sudo bash
    echo "Jellyfin installation complete."
    echo "Access Jellyfin at http://$DOMAIN_NAME:8096"
fi

###################################################################################################################

# Install Immich
if [[ "$USE_IMMICH" =~ ^[Yy]$ ]]; then
    echo "Installing Immich..."
    mkdir -p ~/immich-app
    cd ~/immich-app

    wget -O docker-compose.yml https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml
    wget -O .env https://github.com/immich-app/immich/releases/latest/download/example.env

    sudo docker compose up -d
    echo "Immich installation complete."
    echo "Access Immich at http://$DOMAIN_NAME:2283"
    
    cd
fi

#################################################################################################################

# Install NextCloud
if [[ "$USE_NEXTCLOUD" =~ ^[Yy]$ ]]; then
    echo "Installing NextCloud..."
    
    read -sp "Enter a password for the Nextcloud database user: " DB_PASSWORD
    ### TODO: Ask for pass 2nd time, compare strings to ensure they are equal ###
    echo

    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt update
    sudo apt install -y apache2 unzip php8.2 php8.2-gd php8.2-sqlite3 php8.2-curl php8.2-zip php8.2-xml php8.2-mbstring php8.2-mysql php8.2-bz2 php8.2-intl php8.2-smbclient php8.2-imap php8.2-gmp php8.2-bcmath libapache2-mod-php8.2

    sudo mysql -u root -e "CREATE DATABASE nextcloud;"
    sudo mysql -u root -e "CREATE USER 'nextclouduser'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
    sudo mysql -u root -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextclouduser'@'localhost';"
    sudo mysql -u root -e "FLUSH PRIVILEGES;"

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

    sudo a2ensite nextcloud.conf
    sudo a2enmod rewrite headers env dir mime
    sudo systemctl restart apache2

    echo "Nextcloud installation complete."
    echo "Access Nextcloud at http://$DOMAIN_NAME/nextcloud"

    cd
fi

##############################################################################################################

# Install Home Assistant
if [[ "$USE_HA" =~ ^[Yy]$ ]]; then
    echo "Installing Home Assistant..."

    VB_PKG="virtualbox"
    HA_OS_URL="https://github.com/home-assistant/operating-system/releases/latest/download/hassos_ova-9.5.ova"
    VM_NAME="HomeAssistant"
    RAM_SIZE="2048"
    CPU_COUNT="2"

    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root (use sudo)."
        exit 1
    fi

    echo "Installing VirtualBox..."
    sudo apt update
    sudo apt install -y $VB_PKG

    if ! command -v VBoxManage &>/dev/null; then
        echo "Error: VirtualBox is not installed correctly."
        exit 1
    fi
    echo "VirtualBox installed successfully."

    echo "Downloading Home Assistant OS..."
    wget -q --show-progress "$HA_OS_URL" -O home_assistant.ova

    if [ ! -f home_assistant.ova ]; then
        echo "Error: Failed to download Home Assistant OS."
        exit 1
    fi

    if VBoxManage list vms | grep -q "\"$VM_NAME\""; then
        echo "A VM named $VM_NAME already exists. Skipping import."
    else
        echo "Importing Home Assistant OVA..."
        VBoxManage import home_assistant.ova --vsys 0 --vmname "$VM_NAME"
    fi

    echo "Configuring VM..."
    VBoxManage modifyvm "$VM_NAME" --memory "$RAM_SIZE" --cpus "$CPU_COUNT"
    VBoxManage modifyvm "$VM_NAME" --nic1 nat  # Use NAT for networking
    VBoxManage modifyvm "$VM_NAME" --vrde on  # Enable remote display

    echo "Starting Home Assistant VM..."
    VBoxManage startvm "$VM_NAME" --type headless

    rm -f home_assistant.ova
    echo "Setup complete! Access Home Assistant at http://$DOMAIN_NAME:8123"
fi

##############################################################################################################

echo "Installation complete! Here are the services you installed:"
echo "----------------------------------------------------------------"

if [[ "$USE_TAILSCALE" =~ ^[Yy]$ ]]; then
    echo "Tailscale is running. Your Tailscale IP: $DOMAIN_NAME"
fi

if [[ "$USE_JELLYFIN" =~ ^[Yy]$ ]]; then
    echo "Jellyfin: http://$DOMAIN_NAME:8096"
fi

if [[ "$USE_IMMICH" =~ ^[Yy]$ ]]; then
    echo "Immich: http://$DOMAIN_NAME:2283"
fi

if [[ "$USE_NEXTCLOUD" =~ ^[Yy]$ ]]; then
    echo "Nextcloud: http://$DOMAIN_NAME/nextcloud"
fi

if [[ "$USE_HA" =~ ^[Yy]$ ]]; then
    echo "Home Assistant: http://$DOMAIN_NAME:8123"
fi

echo "Thank you for using My First Home Lab, welcome to the sys admin life!"
