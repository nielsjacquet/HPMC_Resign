#!/usr/bin/env bash

##Colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'
BLUE='\033[0;34m'

function help {
  printf "${GREEN}HELP${NC}\n"
  printf "${NC}use -u to define the apiUrl${NC}\n"
  printf "${NC}use -t to define the apiTokenUrl${NC}\n"
  printf "${NC}Have a nice day${NC}\n"
  printf "${NC}bye${NC}\n"
  }

# while getopts u:t:h: option
# do
#   case "${option}"
#     in
#     u)        url=${OPTARG};;
#     t)   tokenurl=${OPTARG};;
#     h)  help;;
#   esac
# done
#
# printf "${GREEN} echo url: $url${NC}\n"
# printf "${YELLOW} echo tokenurl: $tokenurl${NC}\n"

for arg in "$@"
do
    if [ "$arg" == "--help" ] || [ "$arg" == "-h" ]
    then
        echo "Help argument detected."
    fi
    if [[ "$arg" == "-apiUrl" ]]
    then
      echo "apiUrl :$2"
    fi
    if [[ "$arg" == "-apiTokenUrl" ]]
    then
      echo "apiTokenUrl :$4"
    fi
    echo $#
done
