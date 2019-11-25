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
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"    ##Homedir
sharedResourcesPath="$DIR/_SharedResources"
configDotPlistFolder="$DIR/_SharedResources/ConfigPlists"
provisioningProfilePath="$DIR/_SharedResources/ProvisioningProfile"
extractFile="$DIR/test.txt"
entitlements="$DIR/_TEMP/entitlements.txt"

##Variables
fixDate=$(date +"%Y%m%d - %Hh%M")
codesign="GZ75RPKBFF"
tempFolder=$DIR/_TEMP
payloadFolder="$tempFolder/Payload"
LC_ALL=C

helpFunction()
{
   echo ""
   echo "Usage: $0 -v 2.8 -e api -c dev-plt.plist -a yes -i ipaPath"
   echo -e "\t-v Resigning HPMC 2.8/3.2 version -- REQUIRED"
   echo -e "\t-e entitlements hpmc or api -- REQUIRED"
   echo -e "\t-a resign Agents? yes or no -- OPTIONAL"
   echo -e "\t-i ipaPath -- REQUIRED "
   echo -e "\t-c config.plist replace? --OPTIONAL"
   echo -e "\t\t-usable configs:"
   function readPlist {
      for configPlists in "$configDotPlistFolder"/*
        do
          configname=$(basename $configPlists )
          configFileNameArray+=("$configname")
          configPathArray+=("$configPlists")
        done
      configFileNameArrayLength=${#configFileNameArray[@]}
    }
    function choosePlist {
        for (( i = 0; i < $configFileNameArrayLength; i++ ))
          do
            echo -e "\t\t\t-${configFileNameArray[$i]}"
          done
    }
    readPlist
    choosePlist
    echo -e "\t-o agents ONLY -- OPTIONAL --> IF USED, USE NO OTHER AGRUMENTS THEN -v --REQUIRED "
   exit 1 # Exit script after printing help
}

while getopts "v:e:c:a:i:?:h:o:" opt
do
   case "$opt" in
      v ) versionArg="$OPTARG" ;;
      e ) entitlementsArg="$OPTARG" ;;
      c ) confiArg="$OPTARG" ;;
      a ) agentsArg="$OPTARG" ;;
      i ) ipaArg="$OPTARG" ;;
      o ) agentsOnly="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
      h ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

setIpaNameFunction()
{
  printf "${GREEN}Setting The ipa name${NC}\n"
  ipaName=$(basename "$ipaArg")
  ipaPath="$ipaArg"
  ipaFileExtention="${ipaName##*.}"
  if [[ -z "$ipaArg" ]]
    then
      printf "${RED}There is no ipa specified! Please use -i path/to/ipa.ipa ${NC}\n"
      exit 1
    else
      if [[ $ipaFileExtention = "ipa" ]]
        then
          printf "${BLUE}ipa path: $ipaPath${NC}\n"
          printf "${BLUE}ipa name: $ipaName${NC}\n"
          unZipFunction
      else
        printf "${RED}The app filetype is incorrect${NC}\n"
        exit 1
      fi
  fi
}

unZipFunction()
{
  printf "${GREEN}Unzipping the ipa${NC}\n"
  unzip "$ipaPath" -d $tempFolder
  cd $payloadFolder
  payloadApp=$(ls | grep '.app')
  printf "${BLUE}payloadApp: $payloadApp${NC}\n"
}

setVariablesFunction()
{
  printf "${GREEN}Setting The Variables according to the version${NC}\n"
if [[ -z $versionArg ]]
  then
    printf "${RED}There is no version specified! Please use -v 2.8 or 3.2 ${NC}\n"
    exit 1
  else
    if [[ $versionArg = "2.8" ]]
      then
      resourcesPath="$DIR/HPMC2.8/Resources"
      iosJsPath="$resourcesPath/HybridJS/ios"
      agentFolder="$DIR/HPMC2.8/OriginalAgents"
      printf "${BLUE}Version: $versionArg\n"
      printf "resourcesPath: $resourcesPath\n"
      printf "iosJsPath: $iosJsPath\n"
      printf "agentFolder: $agentFolder${NC}\n"
    fi
    if [[ $versionArg = "3.2" ]]
      then
      resourcesPath="$DIR/HPMC3.2/Resources"
      iosJsPath="$resourcesPath/ios"
      agentFolder="$DIR/HPMC3.2/OriginalAgents"
      printf "${BLUE}Version: $versionArg\n"
      printf "resourcesPath: $resourcesPath\n"
      printf "iosJsPath: $iosJsPath\n"
      printf "agentFolder: $agentFolder${NC}\n"
    fi
fi
}

provisionCheckFunction()
{
  printf "${GREEN}Setting The provisioningProfile${NC}\n"
  cd $provisioningProfilePath
  amountOfprofiles=$(ls | grep -c ".mobileprovision")
  if [[ $amountOfprofiles != 1 ]]
    then
      printf "${RED}There is an issue with the mobileprovision file, please go to the $sharedResourcesPath folder!${NC}\n"
      exit 1
    else
      profiledot=$(ls | grep ".mobileprovision")
      provisioningProfilePath="$provisioningProfilePath/$profiledot"
      printf "${BLUE}ProvisioningProfile: $provisioningProfilePath${NC}\n"
  fi
}

dylibCheckFunction()
{
  printf "${GREEN}Setting dylib${NC}\n"
  cd $resourcesPath
  amountOfdylibs=$(ls | grep -c ".dylib")
  if [[ $amountOfdylibs != 1 ]]
    then
      printf "${RED}There is an issue with the dylib file, please go to the $resourcesPath folder!${NC}\n"
      exit 1
    else
      dylibdotlyb=$(ls | grep ".dylib")
      dylib="$resourcesPath/$dylibdotlyb"
      printf "${BLUE}dylib: $dylib${NC}\n"
  fi
}

jsCheckFunction()
{
  printf "${GREEN}Checking the JS folder${NC}\n"
  if [[ -d "$iosJsPath" ]]
    then
      printf "${BLUE}JavaScript directory: $iosJsPath${NC}\n"
    else
      printf "${RED}JavaScript directory is not available.${NC}\n"
      exit 1
  fi
}

destinationFolderCheckFunction()
{
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

  signedAppsFolder="$signedIpasFolder/Apps"
  if [[ -d "$signedAppsFolder" ]]
    then
      printf "${GREEN}signedAppsFolder directory is available${NC}\n"
      BR
    else
      printf "${RED}signedAppsFolder directory is not available,${GREEN} creating the directory${NC}\n"
      BR
      mkdir "$signedAppsFolder"
  fi

  payloadAppCleaned=${ipaName%????}
  destinationFolder="$DIR/SignedIpas/Apps/$fixDate - $payloadAppCleaned - HPMC_$versionArg"
  if [[ -d "$destinationFolder" ]]
  then
    printf "${GREEN}DestinationFolder directory is available${NC}\n"
    BR
  else
    printf "${RED}DestinationFolder directory is not available,${GREEN} creating the directory${NC}\n"
    BR
    mkdir "$destinationFolder"
  fi

}

getProvisionedDevicesFunction()
{
  printf "${YELLOW}Getting the provisioned devices${GREEN}\n"
  provDevices="$destinationFolder/ProvisionedDevices_$ogIpa.txt"
  LC_ALL=C sed -n '1, /<key>ProvisionedDevices/!p; /<key>ProvisionedDevices/p' "$provisioningProfilePath" >> $extractFile
  LC_ALL=C sed '1,/TeamIdentifier/!d' $extractFile >> "$provDevices"
  printf "${NC}\n"
  rm $extractFile
}

extractEntitlementsFunction()
{
  printf "${GREEN}Extracting the entitlements${BLUE}\n"
  cd $tempFolder/Payload
  payloadApp=$(ls | grep '.app')
  cd $tempFolder
  codesign -d -vv --entitlements entitlements.txt ./Payload/$payloadApp
  printf "${NC}\n"
}

editEntitlementsFunction()
{
  printf "${GREEN}Editing the entitlements\n"
  LC_ALL=C sed -i '' 's/^.*<?xml/<?xml/g' $entitlements
  LC_ALL=C sed -i '' 's/false/true/g' $entitlements
  LC_ALL=C sed -i '' 's/<key>aps-environment<\/key>//g' $entitlements
  LC_ALL=C sed -i '' 's/<string>production<\/string>//g' $entitlements
  cat $entitlements
  printf "${NC}\n"
}

extractVersionFuntion()
{
  infoPlist="$DIR/_TEMP/Payload/$payloadApp/info.plist"
  plutil -convert xml1 $infoPlist
  printf "${GREEN}Extracting the app version${NC}\n"
  buildVersionRude=$(cat $infoPlist | grep -A1 "CFBundleVersion")
  printf "${BLUE}buildVersionRude $buildVersionRude\n"
  buildVersionMinEnd=$(echo ${buildVersionRude%?????????})
  printf "${BLUE}buildIDMinEnd: $buildVersionMinEnd\n"
  buildVersionMinFront=$(echo ${buildVersionMinEnd:35})
  buildVersion=$buildVersionMinFront
  printf "${BLUE}buildVersion: $buildVersion${NC}\n"
}

extractBundleIDFunction()
{
  printf "${GREEN}Extracting the bundle id${NC}\n"
  bundleIDRude=$(cat $infoPlist | grep -A1 "CFBundleIdentifier")
  printf "${BLUE}bundleIDRude: $bundleIDRude\n"
  bundleIDMinEnd=$(echo ${bundleIDRude%?????????})
  printf "${BLUE}bundleIDMinEnd: $bundleIDMinEnd\n"
  bundleIDMinFront=$(echo ${bundleIDMinEnd:38})
  bundleID=$bundleIDMinFront
  printf "${BLUE}bundleID: $bundleID${NC}\n"
}

copyConfigPlistFunction()
{
  printf "${GREEN}Copying the config.plist${BLUE}\n"
  if [[ -z $confiArg ]]
   then
    printf "${BLUE}No external config.plist in place${NC}\n"
    setNewIpaNameFuntion
  else
    case $confiArg in
      dev-plt.plist )
        echo $confiArg
        cp -v "$sharedResourcesPath/ConfigPlists/dev-plt.plist" "$payloadFolder/$payloadApp/Config.plist"
        ;;
      int.plist )
        echo $confiArg
        cp -v "$sharedResourcesPath/ConfigPlists/int.plist" "$payloadFolder/$payloadApp/Config.plist"
        ;;
      dev2.plist )
        echo $confiArg
        cp -v "$sharedResourcesPath/ConfigPlists/dev-plt.plist" "$payloadFolder/$payloadApp/Config.plist"
        ;;
      acc-plt.plist )
        echo $confiArg
        cp -v "$sharedResourcesPath/ConfigPlists/acc-plt.plist" "$payloadFolder/$payloadApp/Config.plist"
        ;;
    esac
  fi
  printf "${NC}\n"
}

setNewIpaNameFuntion()
{
  printf "${GREEN}Setting the new ipa name${BLUE}\n"
  newipaName="$bundleID"_"$buildVersion"_HPMC-"$versionArg".ipa
  printf "${BLUE}newipaName: $newipaName${NC}\n"
}

zipIpaFunction()
{
  printf "${GREEN}Zipping the payloadFolder${NC}\n"
  cd $payloadFolder
  echo payloadFolder $payloadFolder
  find . -name ".DS_Store" -exec rm -rf {} +;
  cd $tempFolder
  zip -r "$newipaName" ./Payload
}

getNewZippedIpaFunction()
{
printf "${GREEN}Grabbing the new and edited ipa${NC}\n"
cd $tempFolder
newZippedIpa=$(ls | grep '.ipa')
printf "${BLUE}getNewZippedIpa: $newZippedIpa ${NC}\n"
}

signHPMCFunction()
{
  printf "${GREEN}signing the app${NC}\n"
  cd $resourcesPath
  printf "${BLUE}ipa: $tempFolder/$newZippedIpa\n"
  printf "dylib: $dylib\n"
  printf "codesign: $codesign\n"
  printf "provisioningProfile: $provisioningProfilePath\n"
  printf "iosJsPath: $iosJsPath\n"
  printf "destinationFolder: $destinationFolder\n"
  printf "entitlements: $entitlements\n"
  printf "newipaName: $newipaName${NC}\n"
  case $entitlementsArg in
    hpmc )
      ./HPMCEnabler "$tempFolder/$newZippedIpa" -inject $dylib -codesign $codesign -p $provisioningProfilePath -j $iosJsPath -n "$newipaName" -v -d "$destinationFolder"
      ;;
    ipa )
      ./HPMCEnabler "$tempFolder/$newZippedIpa" -inject $dylib -codesign $codesign -p $provisioningProfilePath -j $iosJsPath -e $entitlements -n "$newipaName" -v -d "$destinationFolder"
      ;;
  esac
}

resignAgentsFunction()
{
  if [[ $agentsOnly = "yes" ]] || [[ $agentsArg = "yes" ]]
  then
    printf "${GREEN}Resigning the Agents${NC}\n"
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

    cd "$signedAgentsFolder"
    echo "$signedAgentsFolder"
    dateDir=$fixDate" - HPMC "$versionArg
    mkdir "$dateDir"
    echo DateDir: "$dateDir"
    echo agentFolder: "$agentFolder"

    for agents in "$agentFolder"/*
     do
      ogIpa=$(echo "$(basename "$agents")")
      echo "$ogIpa"
      printf "${YELLOW}The ipa that will be signed: ${GREEN}$ogIpa${NC}\n"
      cd "$resourcesPath"
      ./HPMCEnabler "$agentFolder/$ogIpa" -codesign $codesign -p "$provisioningProfilePath" -v -n "$ogIpa" -d "$signedAgentsFolder/$dateDir"
    done
  fi

  printf "${YELLOW}Getting the provisioned devices for the agents folder${GREEN}\n"
  provDevices="$signedAgentsFolder/$dateDir/ProvisionedDevices_agents.txt"
  LC_ALL=C sed -n '1, /<key>ProvisionedDevices/!p; /<key>ProvisionedDevices/p' "$provisioningProfilePath" >> $extractFile
  LC_ALL=C sed '1,/TeamIdentifier/!d' $extractFile >> "$provDevices"
  printf "${NC}\n"
  rm $extractFile
}

cleanupFunction()
{
  cp -v -p -R "$entitlements" "$destinationFolder"
  function copyPlist {
    cd $tempFolder/Payload
    payloadApp=$(ls | grep '.app')
    infoPlist="$DIR/_TEMP/Payload/$payloadApp/info.plist"
    configPlist="$DIR/_TEMP/Payload/$payloadApp/Config.plist"
    cp -v -p -R "$infoPlist" "$destinationFolder"
    cp -v -p -R "$configPlist" "$destinationFolder"
  }
  copyPlist
  rm -rf $tempFolder
}

if [[ $agentsOnly = "yes" ]]
  then
    printf "${GREEN}Option resign only the agents${NC}\n"
    setVariablesFunction
    provisionCheckFunction
    resignAgentsFunction
  else
    if [[ -z $versionArg ]] || [[ -z $entitlementsArg ]] || [[ -z $ipaArg ]]
    then
      helpFunction
    else
      setIpaNameFunction
      setVariablesFunction
      provisionCheckFunction
      dylibCheckFunction
      jsCheckFunction
      destinationFolderCheckFunction
      getProvisionedDevicesFunction
      extractEntitlementsFunction
      editEntitlementsFunction
      extractVersionFuntion
      extractBundleIDFunction
      copyConfigPlistFunction
      setNewIpaNameFuntion
      zipIpaFunction
      getNewZippedIpaFunction
      signHPMCFunction
      resignAgentsFunction
      cleanupFunction
    fi
fi
