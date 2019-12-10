#!/usr/bin/env bash

##cosmetic functions and Variables

##Colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'
BLUE='\033[0;34m'

##Break function for readabillity
function BR {
  echo "  "
}

##DoubleBreak function for readabillity
function DBR {
  echo " "
  echo " "
}

##Paths
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
fixDate=$(date +"%Y%m%d-%Hh%M")
dateDir="$DIR/SignedIpas/Agents/$fixDate"
resourcesPath="$DIR/Resources"
codesign="2RZ9D7SN48"
toBeSignedFolder="$DIR/OriginalAgents"
extractFile="$DIR/test.txt"
agentDir="/opt/mc/connector/Agent"
amountOfProfiles=()

function provisioningProfileCheck {
  for provisioningProfiles in "$resourcesPath"/*
   do
     provisionProfileExtension="${provisioningProfiles##*.}"
     if [ $provisionProfileExtension == "mobileprovision" ]
      then
        amountOfProfiles+=("$provisioningProfiles")
        profilesArrayLength=${#amountOfProfiles[@]}
     fi
  done

  if [[ "$profilesArrayLength" -eq "1" ]]
    then
    provisioningProfile=$(ls "$resourcesPath" | grep ".mobileprovision")
    echo $provisioningProfile
    provisioningProfilePath="$resourcesPath/$provisioningProfile"
  else
    ## insert exit with errorcode
    printf "${RED}No or more than one provisioningProfile in the resource folder.${NC}\n"
    exit 113
  fi
}

##check SignedIpas/Agents folder
function destinationFolderCheck {
  signedIpasFolder="$DIR/SignedIpas"
  if [[ -d "$signedIpasFolder" ]]
    then
      printf "${GREEN}signedIpasFolder directory is available${NC}\n"
      BR
    else
      printf "${RED}signedIpasFolder directory is not available,${GREEN} creating the directory${NC}\n"
      BR
      mkdir "$signedIpasFolder"
  fi

  signedAgentsFolder="$signedIpasFolder/Agents"
  if [[ -d "$signedAgentsFolder" ]]
    then
      printf "${GREEN}signedAgentsFolder directory is available${NC}\n"
      BR
    else
      printf "${RED}signedAgentsFolder directory is not available,${GREEN} creating the directory${NC}\n"
      BR
      mkdir "$signedAgentsFolder"
  fi
}

function DateDir {
  if [[ -d "$dateDir" ]]
  then
    printf "${GREEN}Date directory is available${NC}\n"
    BR
  else
    printf "${RED}Date directory is not available,${GREEN} creating the directory${NC}\n"
    BR
    mkdir "$dateDir"
  fi
}

function getOgIpas {
  for agents in "$toBeSignedFolder"/*
   do
    ogIpa=$(echo "$(basename "$agents")")
    printf "${YELLOW}The ipa that will be signed: ${GREEN}$ogIpa${NC}\n"
    signHPMC
  done
}

##sign with HPMC module
function signHPMC {
  cd $resourcesPath
  echo IPAFILE: $toBeSignedFolder/$ogIpa
  echo codesign: $codesign
  echo $provisioningProfilePath
  ./HPMCEnabler $toBeSignedFolder/$ogIpa -codesign $codesign -p $provisioningProfilePath -v -n $ogIpa -d "$dateDir"
}

##extract the provisioned device from the provisioningProfile
function getProvisionedDevices {
  provDevices="$dateDir""/ProvisionedDevices.txt"
  echo provDevices: $provDevices
  echo provisioningProfilePath:  $provisioningProfilePath
  echo extractFile: $extractFile
  LC_ALL=C  sed -n '1, /<key>ProvisionedDevices/!p; /<key>ProvisionedDevices/p' "$provisioningProfilePath" >> "$extractFile"
  LC_ALL=C  sed '1,/TeamIdentifier/!d' "$extractFile" >> "$provDevices"
  rm $extractFile
}

function copyIpas {
  for ipas in "$dateDir"/*
    do
      extension="${ipas##*.}"
      if [[ $extension == "ipa" ]]
        then
          cp -v -p "$ipas" "$agentDir"
      fi
    done
}
provisioningProfileCheck
destinationFolderCheck
DateDir
getOgIpas
getProvisionedDevices
copyIpas
