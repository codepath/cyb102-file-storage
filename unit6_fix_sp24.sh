#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
none='\033[0m'
yellow='\033[1;33m'

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
##########################################

echo "THIS SCRIPT IS UNDER DEVELOPMENT. PLEASE DO NOT USE IT YET"

echo "[UNIT 6 LAB/PROJECT SPRING 2024 FIX] Starting script..."

CATALYST_INSTALL_PATH=/opt/catalyst
mkdir -p $CATALYST_INSTALL_PATH
pushd $CATALYST_SCRIPTS_PATH

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

#### CATALYST LOCAL INSTALL: CATALYST
CATALYST_INSTALLED=$(curl -k http://catalyst.localhost)
if [[ "$CATALYST_INSTALLED" =~ "<html>" ]]; then
	echo -e "${green}[CATALYST SETUP]${none} Catalyst already running"
else
	echo -e "${yellow}[CATALYST SETUP]${none} INSTALLING CATALYST"

	curl -sL https://raw.githubusercontent.com/sarcb/catalyst-setup-sp24/main/install_catalyst.sh -o install_catalyst.sh

	openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout example.key -out example.crt -subj "/CN=localhost"

	#sed -i "s/docker compose/docker-compose/g" $CATALYST_SCRIPTS_PATH/install_catalyst.sh

	sudo bash install_catalyst.sh https://catalyst.localhost https://authelia.localhost $CATALYST_SCRIPTS_PATH/example.crt $CATALYST_SCRIPTS_PATH/example.key admin:admin:admin@example.com
fi

### CLEANUP 
if [[ $PWD != $CATALYST_SCRIPTS_PATH  ]]; then 
	popd
fi


