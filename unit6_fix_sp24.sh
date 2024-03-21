#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
none='\033[0m'
yellow='\033[1;33m'
bold='\033[1m'

##########################################
############### REFERENCES ###############
##
## CATALYST LOCAL INSTALL:
##	https://catalyst-soar.com/docs/catalyst/admin/install/#local-installation
##
## DOCKER COMPOSE STANDALONE 
##	https://docs.docker.com/compose/install/standalone/
##
## DOCKER 
## 	https://github.com/fmidev/smartmet-server/blob/master/docs/Setting-up-Docker-and-Docker-Compose-(Ubuntu-16.04-and-18.04.1).md
##
## Script developed by rollingcoconut and sarcb 
##########################################

echo "THIS SCRIPT IS UNDER DEVELOPMENT. PLEASE DO NOT USE IT YET"

echo "[UNIT 6 LAB/PROJECT SPRING 2024 FIX] Starting script..."

CATALYST_INSTALL_PATH=/opt/catalyst
mkdir -p $CATALYST_INSTALL_PATH
pushd $CATALYST_INSTALL_PATH

#### CATALYST LOCAL INSTALL: UPDATE /ETC/HOSTS
if ! grep -q "catalyst.localhost" /etc/hosts; then
    echo "127.0.0.1 catalyst.localhost" | sudo tee -a /etc/hosts
    echo "127.0.0.1 authelia.localhost" | sudo tee -a /etc/hosts
fi

#### DOCKER-COMPOSE INSTALL
DOCKER_COMPOSE_INSTALLED=$(docker-compose --version)
if [[ "$DOCKER_COMPOSE_INSTALLED" =~ "Docker Compose version" ]]; then
	echo -e "${green}[DOCKER-COMPOSE SETUP]${none} docker-compose is already installed."
else
	echo -e "${yellow}[DOCKER-COMPOSE SETUP]${none} INSTALLING DOCKER-COMPOSE"
	sudo curl -SL https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
	sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
	sudo chmod +x /usr/local/bin/docker-compose
	sudo /usr/local/bin/docker-compose
fi

#### CATALYST LOCAL INSTALL: DOCKER
DOCKER_ACTIVE=$(systemctl is-active docker)
if [[ "$DOCKER_ACTIVE" == "active" ]]; then
	echo -e "${green}[DOCKER SETUP]${none} Docker is already installed."
else
	echo -e "${yellow}[DOCKER SETUP]${none} INSTALLING DOCKER"
	sudo curl --show-error --location https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	sudo apt-get update
	sudo apt-get install -y docker-ce
	sudo usermod -aG docker ${USER}
fi

#### Check if apache2 is running
APACHE2_ACTIVE=$(systemctl is-active apache2)
if [[ "$APACHE2_ACTIVE" == "active" ]]; then
    echo -e "${yellow}[APACHE2]${none} DISABLING APACHE2"
    sudo service apache2 stop
    sudo systemctl disable apache2
else
    echo -e "${green}[APACHE2]${none} Apache2 is already disabled."
fi

#### CATALYST LOCAL INSTALL: CATALYST
CATALYST_INSTALLED=$(docker compose ls -q --filter name=catalyst-setup-sp24-main)
if [ -n "$CATALYST_INSTALLED" ]; then
	echo -e "${green}[CATALYST SETUP]${none} Catalyst is already running.  Try connecting at https://catalyst.localhost"
    echo -e "\nTo ${red}stop${none} it, use the following command:"
    echo -e "\n  ${bold}docker compose -f /opt/catalyst/catalyst-setup-sp24-main/docker-compose.yml down${none}\n"
    echo -e "To ${yellow}restart${none} it, use the following command:"
    echo -e "\n  ${bold}docker compose -f /opt/catalyst/catalyst-setup-sp24-main/docker-compose.yml up --detach${none}\n"
    exit 0
else
    # verify that this is the first install to prevent arangodb root password issues
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
        sudo bash install_catalyst.sh https://catalyst.localhost https://authelia.localhost $CATALYST_INSTALL_PATH/example.crt $CATALYST_INSTALL_PATH/example.key admin:admin:admin@example.com
    fi
fi

#### VERIFY
CATALYST_INSTALLED=$(docker compose ls -q --filter name=catalyst-setup-sp24-main)
if [ -n "$CATALYST_INSTALLED" ]; then
    echo -e "${green}[CATALYST SETUP]${none} Catalyst is running.  Try connecting at https://catalyst.localhost"
else
    echo -e "${red}[CATALYST SETUP]${none} Catalyst is not running.  Please check the logs for errors."
fi

### CLEANUP 
if [[ $PWD != $CATALYST_INSTALL_PATH  ]]; then 
	popd
fi


