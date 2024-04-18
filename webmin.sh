#!/bin/bash



# Malware detector
MALDET="https://www.rfxn.com/downloads/maldetect-current.tar.gz"

# WebStack Packages .deb
WEB_STACK_CHECK="mysql* rabbitmq* elasticsearch opensearch percona-server* maria* php* nginx* ufw varnish* certbot* redis* webmin"

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
host1=github.com

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
  WEBMIN_PASSWORD=$(head -c 500 /dev/urandom | tr -dc 'a-zA-Z0-9@#%^?=+_[]{}' | fold -w 15 | head -n 1)
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
