#!/bin/bash

# Galaxy central management tool
# This script requires msetup and cryptsetup.
# Needs to be launched as superuser.
#
# Author: Marco Tangaro
# mail: ma.tangaro@gmail.com
# 
# LICENCE: Apache 2.0 software licence

VERSION='0.0.1 (alpha)'
DEBUG=false

################################################################################
# VARIABLES

# date
now=$(date +"-%b-%d-%y-%H%M%S")

# colors for errors and warnings        
red=$(tput setab 0; tput setaf 1)
yellow=$(tput setab 0; tput setaf 3)
none=$(tput sgr0)

# colors for messages
green="\033[32m"
blue="\033[34m"
normal="\033[0m"

# ok and fail variables
_ok="[$green OK $none]"
_stop="[ STOP ]"
_fail=" [$red FAIL $none]"



################################################################################
# GALAXY

IP="90.147.102.96"
URL="http://${IP}/galaxy"
BRAND='INDIGO-CNR testing instance'

supervisord_conf_path=/etc
supervisord_conf_file=${supervisord_conf_path}/supervisord.conf

uwsgi_pidfile=/var/log/galaxy/uwsgi-master.pid

galaxyctl_functions_path=/home/galaxy/galaxycloud-testing
source ${galaxyctl_functions_path}/galaxyctl_functions



################################################################################
# LUKS

luks_script_path=/home/galaxy/galaxycloud-testing

source ${luks_script_path}/luksctl.sh


################################################################################
# ONEDATA



################################################################################
# PRODUCTION ENVIRONMENT SECTION

#____________________________________
# Print out intro banner

function __intro(){
  echo -e "==============================================================="
  echo -e "   ELIXIR-IIB Galaxy Central Management Tool"
  echo -e ""
  echo -e "   Version: ${VERSION}"
  echo -e "   Instance IP: $IP"
  echo -e "   Galaxy url: http://${IP}/galaxy"
  echo -e "   Galaxy brand: $BRAND"
  echo -e "\n   Type \"galaxyctl server help\" to print out options"
  echo -e "==============================================================="
}

#____________________________________
# Show Galaxy production environment help

function __help(){
  echo -e "\nUsage: galaxyctl server <option>"
  echo -e "\nOptions:\n"
  echo -e "  - help [print-out help]\n"
  echo -e "  - status [display server status]\n"
  echo -e "  - init [init services]\n"

  __cryptdev_help
  __galaxy_help
}

#___________________________________
# Galaxy production environment initialisation

function __init(){

  # Encrypted volume section
  # ========================

  __dmsetup_info &>/dev/null
  if [ $? -eq 0 ]; then
    echo -e "\nEncrypted volume: ${_ok}"
  else
    echo -e "\nMounting encrypted volume..."
    __luksopen_cryptdev
    __init
  fi

  
  # Onedata section
  # ===============

  
  # Galaxy section
  # ==============

  __galaxy_curl &> /dev/null
  code=$?
  if [[ $code -eq "0" ]]; then
    echo -e "\nGalaxy server on-line: ${_ok}"
  else
    __start_galaxy
  fi

  # TODO if galaxy is not up, check supervisor, if supervisor is running check uwsgi master state
}

#____________________________________
# Production environment options

if [ "$1" == server ]; then
  __intro
  if [ "$2" == 'help' ]; then __help; fi
  source ${cryptdev_conf_file}
  if [ "$2" == 'init' ]; then __init; fi
  if [ "$2" == 'status' ]; then __cryptdev_status; __galaxy_url_status; fi
fi
