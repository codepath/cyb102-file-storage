#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
none='\033[0m'
yellow='\033[1;33m'
bold='\033[1m'

export DEBIAN_FRONTEND=noninteractive

echo "[UNIT 6 LAB/PROJECT SPRING 2024 FIX] Starting script..."

# Check if the user is root
if [ "$EUID" -ne 0 ]; then
    echo -e "${red}[ERROR]${none} Please run using sudo."
    exit 1
fi

# Add Docker's official GPG key from the Ubuntu keyserver
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 7EA0A9C3F273FCD8

# Installing unzip to ensure system won't crash
if ! dpkg -s unzip > /dev/null; then
    echo "${red}[UNZIP]${none} Unzip not installed.  Installing now..."
    apt install unzip -y
    echo -e "${green}[UNZIP]${none} Unzip installed."
fi

CATALYST_INSTALL_PATH=/opt/catalyst
mkdir -p $CATALYST_INSTALL_PATH
pushd $CATALYST_INSTALL_PATH

# Update /etc/hosts
if ! grep -q "catalyst.localhost" /etc/hosts; then
    echo "127.0.0.1 catalyst.localhost" | sudo tee -a /etc/hosts
    echo "127.0.0.1 authelia.localhost" | sudo tee -a /etc/hosts
fi

# Check and remove existing Docker Compose
DOCKER_COMPOSE_INSTALLED=$(docker-compose --version 2>/dev/null || true)
if [[ "$DOCKER_COMPOSE_INSTALLED" =~ "Docker Compose version" ]]; then
    echo -e "${yellow}[DOCKER-COMPOSE UNINSTALL]${none} Removing existing Docker Compose installation..."
    sudo rm -f /usr/local/bin/docker-compose
    sudo rm -f /usr/bin/docker-compose
    echo -e "${green}[DOCKER-COMPOSE UNINSTALL]${none} Existing Docker Compose removed."
fi

# Docker Compose Setup (architecture-specific)
echo -e "${yellow}[DOCKER-COMPOSE SETUP]${none} INSTALLING DOCKER-COMPOSE"
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" ]]; then
    COMPOSE_ARCH="arm64"
elif [[ "$ARCH" == "x86_64" ]]; then
    COMPOSE_ARCH="x86_64"
else
    echo -e "${red}[DOCKER-COMPOSE]${none} Unsupported architecture: $ARCH"
    exit 1
fi

sudo curl -SL "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-linux-${COMPOSE_ARCH}" -o /usr/local/bin/docker-compose
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo /usr/local/bin/docker-compose

# Docker Setup
echo -e "${yellow}[DOCKER SETUP]${none} INSTALLING DOCKER"
ARCHITECTURE=$(dpkg --print-architecture)
echo "deb [arch=${ARCHITECTURE}] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo curl --show-error --location https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-get update -y
sudo apt-get install -y docker-ce
sudo usermod -aG docker ${USER}

# Docker socket activation fix
echo -e "${yellow}[DOCKER FIX]${none} Ensuring docker.socket is running..."
sudo systemctl enable docker.socket
sudo systemctl start docker.socket

# Patch docker.service to disable socket activation
DOCKER_SERVICE_FILE="/lib/systemd/system/docker.service"
if grep -q "fd://" "$DOCKER_SERVICE_FILE"; then
    echo -e "${yellow}[DOCKER FIX]${none} Patching docker.service to remove socket activation..."
    sudo sed -i 's|ExecStart=/usr/bin/dockerd .*|ExecStart=/usr/bin/dockerd|' "$DOCKER_SERVICE_FILE"
    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl restart docker
else
    echo -e "${green}[DOCKER FIX]${none} docker.service already patched."
fi

# Confirm Docker is active
if systemctl is-active --quiet docker; then
    echo -e "${green}[DOCKER]${none} Docker daemon is running."
else
    echo -e "${red}[DOCKER]${none} Docker failed to start. Please check system logs."
    exit 1
fi

# Apache2 check
APACHE2_ACTIVE=$(systemctl is-active apache2)
if [[ "$APACHE2_ACTIVE" == "active" ]]; then
    echo -e "${yellow}[APACHE2]${none} DISABLING APACHE2"
    sudo service apache2 stop
    sudo systemctl disable apache2
else
    echo -e "${green}[APACHE2]${none} Apache2 is already disabled."
fi

# NGINX check
NGINX_ACTIVE=$(systemctl is-active nginx)
if [[ "$NGINX_ACTIVE" == "active" ]]; then
    echo -e "${yellow}[NGINX]${none} Stopping NGINX"
    sudo service nginx stop
else
    echo -e "${green}[NGINX]${none} Nginx is already stopped."
fi

# Catalyst Docker check
CATALYST_INSTALLED=$(docker compose ls -q --filter name=catalyst-setup-sp24-main)
if [ -n "$CATALYST_INSTALLED" ]; then
    echo -e "${green}[CATALYST SETUP]${none} Catalyst is already running.  Try connecting at https://catalyst.localhost"
    echo -e "\nTo ${red}stop${none} it, use the following command:"
    echo -e "\n  ${bold}docker compose -f /opt/catalyst/catalyst-setup-sp24-main/docker-compose.yml down${none}\n"
    echo -e "To ${yellow}restart${none} it, use the following command:"
    echo -e "\n  ${bold}docker compose -f /opt/catalyst/catalyst-setup-sp24-main/docker-compose.yml up --detach${none}\n"
    exit 0
else
    if [ -n "$(docker volume ls -q --filter name=catalyst-setup-sp24-main_arangodb)" ]; then
        echo "${yellow}[CATALYST SETUP]${none} Catalyst seems to already be installed, but is not currently running."
        echo -e "\nTo ${green}start${none} it, use the following command:"
        echo -e "\n  ${bold}docker compose -f /opt/catalyst/catalyst-setup-sp24-main/docker-compose.yml up --detach${none}\n"
        echo -e "To ${red}stop${none} it, use the following command:"
        echo -e "\n  ${bold}docker compose -f /opt/catalyst/catalyst-setup-sp24-main/docker-compose.yml down${none}\n"
        exit 1
    else
        echo -e "${yellow}[CATALYST SETUP]${none} INSTALLING CATALYST"
        curl -sL https://raw.githubusercontent.com/sarcb/catalyst-setup-sp24/main/install_catalyst.sh -o install_catalyst.sh
        openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout example.key -out example.crt -subj "/CN=localhost"
        yes | sudo bash install_catalyst.sh https://catalyst.localhost https://authelia.localhost $CATALYST_INSTALL_PATH/example.crt $CATALYST_INSTALL_PATH/example.key admin:admin:admin@example.com
    fi
fi

# Final check
CATALYST_INSTALLED=$(docker compose ls -q --filter name=catalyst-setup-sp24-main)
if [ -n "$CATALYST_INSTALLED" ]; then
    echo -e "${green}[CATALYST SETUP]${none} Catalyst is running.  Try connecting at https://catalyst.localhost"
else
    echo -e "${red}[CATALYST SETUP]${none} Catalyst is not running.  Please check the logs for errors."
fi

# Cleanup
if [[ $PWD != $CATALYST_INSTALL_PATH ]]; then 
    popd
fi
