#!/bin/bash
#=================================================================================#
#        MagenX e-commerce stack for Magento 2                                    #
#        Copyright (C) 2013-present admin@magenx.com                              #
#        All rights reserved.                                                     #
#=================================================================================#
SELF=$(basename $0)
MAGENX_VERSION=$(curl -s https://api.github.com/repos/magenx/Magento-2-server-installation/tags 2>&1 | head -3 | grep -oP '(?<=")\d.*(?=")')
MAGENX_BASE="https://magenx.sh"
###################################################################################
###                              REPOSITORY AND PACKAGES                        ###
###################################################################################

# Github installation repository raw url
MAGENX_INSTALL_GITHUB_REPO="https://raw.githubusercontent.com/magenx/Magento-2-server-installation/master"

# Magento
VERSION_LIST=$(curl -s https://api.github.com/repos/magento/magento2/tags 2>&1 | grep -oP '(?<=name": ").*(?=")' | sort -r)
PROJECT="composer create-project --repository-url=https://repo.magento.com/ magento/project-community-edition"

COMPOSER_NAME="8c681734f22763b50ea0c29dff9e7af2" 
COMPOSER_PASSWORD="02dfee497e669b5db1fe1c8d481d6974" 

## Version lock
COMPOSER_VERSION="2.2"
RABBITMQ_VERSION="3.12*"
MARIADB_VERSION="10.11"
ELASTICSEARCH_VERSION="7.x"
VARNISH_VERSION="73"
REDIS_VERSION="7"
NODE_VERSION="18"
NVM_VERSION="0.39.7"

# Repositories
MARIADB_REPO_CONFIG="https://downloads.mariadb.com/MariaDB/mariadb_repo_setup"

# Nginx configuration
NGINX_VERSION=$(curl -s http://nginx.org/en/download.html | grep -oP '(?<=gz">nginx-).*?(?=</a>)' | head -1)
MAGENX_NGINX_GITHUB_REPO="https://raw.githubusercontent.com/magenx/Magento-nginx-config/master/"
MAGENX_NGINX_GITHUB_REPO_API="https://api.github.com/repos/magenx/Magento-nginx-config/contents/magento2"

# Debug Tools
MYSQL_TUNER="https://raw.githubusercontent.com/major/MySQLTuner-perl/master/mysqltuner.pl"

# Malware detector
MALDET="https://www.rfxn.com/downloads/maldetect-current.tar.gz"

# WebStack Packages .deb
WEB_STACK_CHECK="mysql* rabbitmq* elasticsearch opensearch percona-server* maria* php* nginx* ufw varnish* certbot* redis* webmin"

EXTRA_PACKAGES="curl jq gnupg2 auditd apt-transport-https apt-show-versions ca-certificates lsb-release make autoconf snapd automake libtool uuid-runtime \
perl openssl unzip screen nfs-common inotify-tools iptables smartmontools mlocate vim wget sudo apache2-utils \
logrotate git netcat-openbsd patch ipset postfix strace rsyslog geoipupdate moreutils lsof sysstat acl attr iotop expect imagemagick snmp"

PERL_MODULES="liblwp-protocol-https-perl libdbi-perl libconfig-inifiles-perl libdbd-mysql-perl libterm-readkey-perl"

PHP_PACKAGES=(cli fpm common mysql zip lz4 gd mbstring curl xml bcmath intl ldap soap oauth apcu)
###################################################################################
###                                    COLORS                                   ###
###################################################################################
RED="\e[31;40m"
GREEN="\e[32;40m"
YELLOW="\e[33;40m"
WHITE="\e[37;40m"
BLUE="\e[0;34m"
### Background
DGREYBG="  \e[100m"
BLUEBG="  \e[1;44m"
REDBG="  \e[41m"
### Styles
BOLD="\e[1m"
### Reset
RESET="\e[0m"
###################################################################################
###                            ECHO MESSAGES DESIGN                             ###
###################################################################################
WHITETXT () {
        MESSAGE=${@:-"${RESET}Error: No message passed"}
        echo -e "  ${WHITE}${MESSAGE}${RESET}"
}
BLUETXT () {
        MESSAGE=${@:-"${RESET}Error: No message passed"}
        echo -e "  ${BLUE}${MESSAGE}${RESET}"
}
REDTXT () {
        MESSAGE=${@:-"${RESET}Error: No message passed"}
        echo -e "  ${RED}${MESSAGE}${RESET}"
}
GREENTXT () {
        MESSAGE=${@:-"${RESET}Error: No message passed"}
        echo -e "  ${GREEN}${MESSAGE}${RESET}"
}
YELLOWTXT () {
        MESSAGE=${@:-"${RESET}Error: No message passed"}
        echo -e "  ${YELLOW}${MESSAGE}${RESET}"
}
BLUEBG () {
        MESSAGE=${@:-"${RESET}Error: No message passed"}
        echo -e "${BLUEBG}${MESSAGE}${RESET}"
}
pause () {
   read -p "  $*"
}
_echo () {
  echo -en "  $@"
}

PACKAGES_INSTALLED () {
GREENTXT "Installed: "
apt -qq list --installed $@ 2>/dev/null | awk '{print "   " $0}'
}
###################################################################################
###                            ARROW KEYS UP/DOWN MENU                          ###
###################################################################################
updown_menu () {
i=1;for items in $(echo $1); do item[$i]="${items}"; let i=$i+1; done
i=1
echo -e "\n  Use up/down arrow keys then press [ Enter ] to select $2"
while [ 0 ]; do
  if [ "$i" -eq 0 ]; then i=1; fi
  if [ ! "${item[$i]}" ]; then let i=i-1; fi
  echo -en "\r                                 " 
  echo -en "\r${item[$i]}"
  read -sn 1 selector
  case "${selector}" in
    "B") let i=i+1;;
    "A") let i=i-1;;
    "") echo; read -sn 1 -p "  [?] To confirm [ "$(echo -e $BOLD${item[$i]}$RESET)" ] press "$(echo -e $BOLD$GREEN"y"$RESET)" or "$(echo -e $BOLD$RED"n"$RESET)" for new selection" confirm
      if [[ "${confirm}" =~ ^[Yy]$  ]]; then
        printf -v "$2" '%s' "${item[$i]}"
        break
      else
        echo
        echo -e "\n  Use up/down arrow keys then press [ Enter ] to select $2"
      fi
      ;;
  esac
done }
###################################################################################
###           CHECK IF ROOT AND CREATE DATABASE TO SAVE ALL SETTINGS            ###
###################################################################################
echo ""
echo ""
# root?
if [[ ${EUID} -ne 0 ]]; then
  echo
  REDTXT "[!] This script must be run as root user!"
  YELLOWTXT "[!] Login as root and run this script again."
  exit 1
else
  GREENTXT "PASS: ROOT!"
fi

# Config path
MAGENX_CONFIG_PATH="/opt/magenx/config"
if [ ! -d "${MAGENX_CONFIG_PATH}" ]; then
  mkdir -p ${MAGENX_CONFIG_PATH}
fi

# SQLite check, create database path and command
if ! which sqlite3 >/dev/null; then
  echo ""
  YELLOWTXT "[!] SQLite is not installed on this system!"
  YELLOWTXT "[!] Installing..."
  echo ""
  echo ""
  apt update
  apt -y install sqlite3
fi

SQLITE3_DB="magenx.db"
SQLITE3_DB_PATH="${MAGENX_CONFIG_PATH}/${SQLITE3_DB}"
SQLITE3="sqlite3 ${SQLITE3_DB_PATH}"
if [ ! -f "${SQLITE3_DB_PATH}" ]; then
  ${SQLITE3} "" ""

# Create base tables to save configuration
${SQLITE3} "CREATE TABLE IF NOT EXISTS system(
   machine_id             text,
   distro_name            text,
   distro_version         text,
   web_stack              text,
   timezone               text,
   system_test            text,
   ssh_port               text,
   terms                  text,
   system_update          text,
   php_version            text,
   phpmyadmin_password    text,
   webmin_password        text,
   mysql_root_password    text,
   elasticsearch_password text
   );"
   
${SQLITE3} "CREATE TABLE IF NOT EXISTS magento(
   env                       text,
   mode                      text,
   redis_password            text,
   rabbitmq_password         text,
   indexer_password          text,
   version_installed         text,
   domain                    text,
   owner                     text,
   php_user                  text,
   root_path                 text,
   database_host             text,
   database_name             text,
   database_user             text,
   database_password         text,
   admin_login               text,
   admin_password            text,
   admin_email               text,
   locale                    text,
   admin_path                text,
   crypt_key                 text,
   tfa_key                   text,
   private_ssh_key           text,
   public_ssh_key            text,
   github_actions_private_ssh_key    text,
   github_actions_public_ssh_key     text
   );"
   
${SQLITE3} "CREATE TABLE IF NOT EXISTS menu(
   lemp        text,
   magento     text,
   database    text,
   install     text,
   config      text,
   csf         text,
   webmin      text
   );"
   
${SQLITE3} "INSERT INTO menu (lemp, magento, database, install, config, csf, webmin)
 VALUES('-', '-', '-', '-', '-', '-', '-');"
fi
###################################################################################
###                              CHECK IF WE CAN RUN IT                         ###
###################################################################################
## Ubuntu Debian
## Distro detectction
distro_error() {
  echo ""
  REDTXT "[!] ${OS_NAME} ${OS_VERSION} detected"
  echo ""
  echo " Unfortunately, your operating system distribution and version are not supported by this script"
  echo " Supported: Ubuntu 20|22.04; Debian 11|12"
  echo " Please email admin@magenx.com and let us know if you run into any issues"
  echo ""
  exit 1
}

# Check if distribution name and version are already in the database
DISTRO_INFO=($(${SQLITE3} -list -separator '  ' "SELECT distro_name, distro_version FROM system;"))
if [ -n "${DISTRO_INFO[0]}" ]; then
  DISTRO_NAME="${DISTRO_INFO[0]}"
  DISTRO_VERSION="${DISTRO_INFO[1]}"
  GREENTXT "PASS: [ ${DISTRO_NAME} ${DISTRO_VERSION} ]"
else
  # Detect distribution name and version
  if [ -f "/etc/os-release" ]; then
    . /etc/os-release
    DISTRO_NAME="${NAME}"
    DISTRO_VERSION="${VERSION_ID}"

    # Check if distribution is supported
    if [ "${DISTRO_NAME%% *}" == "Ubuntu" ] && [[ "${DISTRO_VERSION}" =~ ^(20.04|22.04) ]]; then
      DISTRO_NAME="Ubuntu"
    elif [ "${DISTRO_NAME%% *}" == "Debian" ] && [[ "${DISTRO_VERSION}" =~ ^(11|12) ]]; then
      DISTRO_NAME="Debian"
    else
      distro_error
    fi

    # Confirm distribution detection with user input
    echo ""
    _echo "${YELLOW}[?]${REDBG}${BOLD}[ ${DISTRO_NAME} ${DISTRO_VERSION} ]${RESET} ${YELLOW}detected correctly ? [y/n][n]: ${RESET}"
    read distro_detect
    if [ "${distro_detect}" = "y" ]; then
      echo ""
      GREENTXT "PASS: [ ${DISTRO_NAME} ${DISTRO_VERSION} ]"
      # Get machine id
      MACHINE_ID="$(cat /etc/machine-id)"
      ${SQLITE3} "INSERT INTO system (machine_id, distro_name, distro_version) VALUES ('${MACHINE_ID}', '${DISTRO_NAME}', '${DISTRO_VERSION}');"
    else
      distro_error
    fi
  else
    distro_error
  fi
fi

# network is up?
host1=${MAGENX_BASE}
host2=github.com

RESULT=$(((ping -w3 -c2 ${host1} || ping -w3 -c2 ${host2}) > /dev/null 2>&1) && echo "up" || (echo "down" && exit 1))
if [[ ${RESULT} == up ]]; then
  GREENTXT "PASS: NETWORK IS UP. GREAT, LETS START!"
  else
  echo ""
  REDTXT "[!] Network is down ?"
  YELLOWTXT "[!] Please check your network settings."
  echo ""
  echo ""
  exit 1
fi

# install packages to run CPU and HDD test
dpkg-query -l curl time bc bzip2 tar >/dev/null || { echo; echo; apt update -o Acquire::ForceIPv4=true; apt -y install curl time bc bzip2 tar; }

fi


###################################################################################
###                                  WEBMIN INSTALLATION                        ###
###################################################################################
"webmin")
echo ""
echo ""
_echo "[?] Install Webmin Control Panel ? [y/n][n]: "
DOMAIN=$(${SQLITE3} "SELECT domain FROM magento LIMIT 1;")
OWNER=$(${SQLITE3} "SELECT owner FROM magento LIMIT 1;")
ADMIN_EMAIL=$(${SQLITE3} "SELECT admin_email FROM magento LIMIT 1;")
read webmin_install
if [ "${webmin_install}" == "y" ];then
 echo ""
 YELLOWTXT "Webmin installation:"
 echo ""
 curl -s -O https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh
 bash setup-repos.sh
 apt update
 apt -y install webmin
if [ "$?" = 0 ]; then
 WEBMIN_PORT=$(shuf -i 17556-17728 -n 1)
 sed -i 's/theme=gray-theme/theme=authentic-theme/' /etc/webmin/config
 sed -i 's/preroot=gray-theme/preroot=authentic-theme/' /etc/webmin/miniserv.conf
 sed -i "s/port=10000/port=${WEBMIN_PORT}/" /etc/webmin/miniserv.conf
 sed -i "s/listen=10000/listen=${WEBMIN_PORT}/" /etc/webmin/miniserv.conf
 sed -i '/keyfile=\|certfile=/d' /etc/webmin/miniserv.conf
 echo "keyfile=/etc/letsencrypt/live/${DOMAIN}/privkey.pem" >> /etc/webmin/miniserv.conf
 echo "certfile=/etc/letsencrypt/live/${DOMAIN}/cert.pem" >> /etc/webmin/miniserv.conf
 
  if [ -f "/usr/local/csf/csfwebmin.tgz" ]; then
    perl /usr/share/webmin/install-module.pl /usr/local/csf/csfwebmin.tgz >/dev/null 2>&1
    GREENTXT "Installed CSF Firewall plugin"
  fi
  
  echo "webmin_${OWNER}:\$1\$84720675\$F08uAAcIMcN8lZNg9D74p1:::::$(date +%s):::0::::" > /etc/webmin/miniserv.users
  sed -i "s/root:/webmin_${OWNER}:/" /etc/webmin/webmin.acl
  WEBMIN_PASSWORD=$(head -c 500 /dev/urandom | tr -dc 'a-zA-Z0-9@#%^?=+_[]{}()' | fold -w 15 | head -n 1)
  /usr/share/webmin/changepass.pl /etc/webmin/ webmin_${OWNER} "${WEBMIN_PASSWORD}"
  
  systemctl enable webmin
  /etc/webmin/restart

  echo
  GREENTXT "Webmin installed - OK"
  echo
  YELLOWTXT "[!] Webmin Port: ${WEBMIN_PORT}"
  YELLOWTXT "[!] User: webmin_${OWNER}"
  YELLOWTXT "[!] Password: ${WEBMIN_PASSWORD}"
  echo ""
  REDTXT "[!] PLEASE ENABLE TWO-FACTOR AUTHENTICATION!"
  
  ${SQLITE3} "UPDATE system SET webmin_password = '${WEBMIN_PASSWORD}';"
  else
   echo
   REDTXT "Webmin installation error"
  fi
  else
   echo
   YELLOWTXT "Webmin installation was skipped by user input."
fi
echo
echo
pause '[] Press [Enter] key to show menu'
echo
;;
"exit")
REDTXT "[!] Exit"
exit
;;

###################################################################################
###                             CATCH ALL MENU - THE END                        ###
###################################################################################
