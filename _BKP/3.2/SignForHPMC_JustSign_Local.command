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
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"  ##Homedir
fixDate=$(date +"%Y%m%d - %Hh%M")                                   ##Block the date and hour for folder creation
resourcesPath="$DIR/Resources"                                      ##path to the resource folder
# codesign="2RZ9D7SN48"                                               ##the developer certificate
codesign="GZ75RPKBFF"                                               ##the developer certificate
iosJsPath="$DIR/Resources/HybridJS/ios"                             ##path to the jsfolder
entitlements="$DIR/_TEMP/entitlements.txt"                          ##temp path used for the entitlements
toBeSignedFolder="$DIR/ToBeSigned"                                  ##path for the ipas that needs to signed
payloadFolder="$toBeSignedFolder/Payload"                           ##payloadFolder
tempFolder="$DIR/_TEMP"                                             ##Temp folder for extract the ipa etc
extractFile="$DIR/test.txt"                                         ##used for the extraction of the devices in the provisioningProfile
LC_ALL=C

##if toBeSignedFolder is empty exit the script
function ipaCheck {
  for ipasToBeSigned in "$toBeSignedFolder"/*
    do
      ipaFileExtentions="${ipasToBeSigned##*.}"                     ##extract just the FileExtention without the dot
      echo File to be signed: $ipasToBeSigned
      echo FileExtention: $ipaFileExtentions
      if [ $ipaFileExtentions == "ipa" ]                            ##if the FileExtention equals ipa
        then
          amountOfIpas+=("$ipasToBeSigned")                         ##put the file in an array
          ipaArrayLength=${#amountOfIpas[@]}                        ##Get the array length for the next statement
        fi
    done
  if [[ $ipaArrayLength < "1" ]]                                    ## if the array length is less than 1, exit the script
   then
    echo no ipa present in the toBeSignedFolder: $toBeSignedFolder
    exit 113                                                        ##exit with code 113
  fi
  }

##allround function to check the files in the resource folder. Use fileCheck "extention"
function fileCheck() {                                                                        ##function with arguments where the argument is a FileExtention
  for files in "$resourcesPath"/*                                                             ##search for all files in the recourse folder
    do
      FileExtention="${files##*.}"                                                            ##Get the FileExtention for every file in the folder
      if [ $FileExtention == $1 ]                                                             ##If the extension matches the one with the argument
        then
          amountOfFiles+=("$files")                                                           ##put the file in an array
          fileArrayLength=${#amountOfFiles[@]}                                                ##get the ArrayLength
        fi
    done
      if [[ "$fileArrayLength" -eq "1" ]]                                                     ##if the ArrayLength is greater than 1 exit the script
        then
          case $1 in                                                                          ##case of the extention in the argument
            mobileprovision )
              printf "${BLUE}-----------------------------------------------------${NC}\n"
              provisioningProfile=$(ls "$resourcesPath" | grep ".$1")                         ##get the file and put it in a var
              echo provisioningProfile: $provisioningProfile
              provisioningProfilePath="$resourcesPath/$provisioningProfile"                   ##describe the path for the file
              echo provisioningProfilePath: $provisioningProfilePath
              ;;
            dylib )
            printf "${BLUE}-----------------------------------------------------${NC}\n"
              dylib=$(ls "$resourcesPath" | grep ".$1")
              echo dylib: $dylib
              dylibPath="$resourcesPath/$dylib"
              echo dylibPath: $dylibPath
              ;;
          esac
        else
        printf "${RED}None or more than one $1(s) in the resource folder.${NC}\n"
        exit 113                                                                              ##exit the script when there is more than one of the argumented filetypes
      fi
  amountOfFiles=()                                                                            ##Clear the array
  fileArrayLength=""                                                                          ##clear the fileArrayLength var
}

##check for jsfolder, else exit the script
function jsCheck {
  if [[ -d "$iosJsPath" ]]
    then
      printf "${BLUE}-----------------------------------------------------${NC}\n"
      printf "JavaScript directory: $iosJsPath\n"
      BR
    else
      printf "${RED}JavaScript directory is not available.${NC}\n"
      BR
      exit 113
  fi
}

##check SignedIpas/apps folder
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

  ipaArchiveFolder="$DIR/OriginalipaArchive"
  if [[ -d "$ipaArchiveFolder" ]]
    then
      printf "${GREEN}OriginalipaArchive directory is available${NC}\n"
      BR
    else
      printf "${RED}OriginalipaArchive directory is not available,${GREEN} creating the directory${NC}\n"
      BR
      mkdir "$ipaArchiveFolder"
  fi

}

##create destinationfolder
function destinationFolderCreation {
  payloadAppCleaned=${ogIpa%????}
  destinationFolder="$DIR/SignedIpas/Apps/$fixDate - $payloadAppCleaned"
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

##Get a list from all ipas in the toBeSignedFolder and pass it to the rest of the script
function getOgIpa {
  printf "${GREEN}Get the og app name${NC}\n"
  for apps in "$toBeSignedFolder"/*                                             ##for every file in the folder
   do
    ogIpa=$(echo "$(basename "$apps")")                                         ##Get the filename with extention
    printf "${YELLOW}The ipa that will be processed: ${GREEN}$ogIpa${NC}\n"
    destinationFolderCreation                                                   ##create a destinationFolder
    getProvisionedDevices                                                       ##get the devices list in the provisioningProfile
    unZip                                                                       ##unzip the ipa to extract the entitlements
  done
}

##extract the device part from the provisioningProfile for reference
function getProvisionedDevices {
  printf "${YELLOW}Getting the provisioned devices${GREEN}\n"
  provDevices="$destinationFolder/ProvisionedDevices_$ogIpa.txt"
  LC_ALL=C sed -n '1, /<key>ProvisionedDevices/!p; /<key>ProvisionedDevices/p' "$resourcesPath/$provisioningProfile" >> $extractFile
  LC_ALL=C sed '1,/TeamIdentifier/!d' $extractFile >> "$provDevices"
  printf "${NC}\n"
  rm $extractFile
}

##unzip ipa
function unZip {
  printf "${GREEN}Unzipping the ipa${NC}\n"
  cd $toBeSignedFolder
  unzip "$ogIpa" -d $tempFolder                                                 ##unzip the ipa in a temp folder
  extractEntitlements
}

##extract entitlements
function extractEntitlements {
  printf "${GREEN}Extracting the entitlements${NC}\n"
  cd $tempFolder/Payload
  payloadApp=$(ls | grep '.app')
  cd $tempFolder
  codesign -d -vv --entitlements entitlements.txt ./Payload/$payloadApp         ##codesign the entitlements
  editEntitlements
}

##Edit entitlements
function editEntitlements {
  printf "${GREEN}Editing the entitlements\n"
  LC_ALL=C sed -i '' 's/^.*<?xml/<?xml/g' $entitlements                         ##clean up the first bytes of rubbish
  LC_ALL=C sed -i '' 's/false/true/g' $entitlements                             ## set the get-task-allow to true
  LC_ALL=C sed -i '' 's/<key>aps-environment<\/key>//g' $entitlements
  LC_ALL=C sed -i '' 's/<string>production<\/string>//g' $entitlements
  cat $entitlements
  printf "${NC}\n"                          ## set the get-task-allow to true
  extractVersion
}

function extractVersion {                                                       ##extract the app version for naming sceme
  infoPlist="$DIR/_TEMP/Payload/$payloadApp/info.plist"
  plutil -convert xml1 $infoPlist
  printf "${GREEN}Extracting the app version${NC}\n"
  buildVersionRude=$(cat $infoPlist | grep -A1 "CFBundleVersion")
  echo buildVersionRude $buildVersionRude
  buildVersionMinEnd=$(echo ${buildVersionRude%?????????})
  echo buildIDMinEnd: $buildVersionMinEnd
  buildVersionMinFront=$(echo ${buildVersionMinEnd:35})
  echo $buildIDMinFront
  buildVersion=$buildVersionMinFront
  extractBundleID
}

function extractBundleID {                                                      ##extract the app bundleID for naming sceme
  printf "${GREEN}Extracting the bundle id${NC}\n"
  bundleIDRude=$(cat $infoPlist | grep -A1 "CFBundleIdentifier")
  echo bundleIDRude: $bundleIDRude
  bundleIDMinEnd=$(echo ${bundleIDRude%?????????})
  echo bundleIDMinEnd: $bundleIDMinEnd
  bundleIDMinFront=$(echo ${bundleIDMinEnd:38})
  echo bundleIDMinFront: $bundleIDMinFront
  bundleID=$bundleIDMinFront
  setAppName
}

function setAppName {                                                           ##create a new name for the ipa
  printf "${GREEN}setting the app name${NC}\n"
  appName=$(echo ${ogIpa%????})
  if [[ $bundleID == *"debughelper"* ]] || [[ $bundleID == *"btp"* ]] ||  [[ $bundleID == *"Gatekeeper"* ]] || [[ $bundleID == *"myucb"* ]]  ##if the bundle id contains one of these options set the projectName
   then
     projectName="myUCB"
   else
     projectName=$appName                                                       ##else the projectName = appname
  fi
signHPMC
}

##sign with HPMC module
function signHPMC {
  printf "${GREEN}signing the app for HPMC${NC}\n"
  cd $resourcesPath
  printf "${YELLOW}OGIPA: $toBeSignedFolder/$ogIpa\n"
  printf "dylib: $dylib\n"
  printf "codesign: $codesign\n"
  printf "provisioningProfile: $provisioningProfilePath\n"
  printf "iosJsPath: $iosJsPath\n"
  printf "destinationFolder: $destinationFolder\n"
  printf "entitlements: $entitlements${NC}\n"
  ipaName=$bundleID"_"$buildVersion"-HPMC-Enabled.ipa"
  echo "original ipa file = $ogIpa"
  echo "orginal ipa path = $toBeSignedFolder/$ogIpa"
  echo "newipaName = $ipaName"
  ##sign and Rename ipa file
  ./HPMCEnabler "$toBeSignedFolder/$ogIpa" -inject $dylib -codesign $codesign -p $provisioningProfilePath -j $iosJsPath -e $entitlements -n "$ipaName" -v -d "$destinationFolder"
cleanup
}

##Cleanup to be signed toBeSignedFolder
function cleanup {
  printf "${GREEN}folder cleanup${NC}\n"
  ##create date and time folder
  dateDir="$DIR/OriginalipaArchive/$fixDate - $payloadAppCleaned"
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
  DateDir

##copy payload and entitlements to created folder
  cp -v -p -R "$entitlements" "$dateDir"
  function copyPlist {
    cd $tempFolder/Payload
    payloadApp=$(ls | grep '.app')
    printf "${YELLOW} $payloadApp ${NC}\n"
    infoPlist="$DIR/_TEMP/Payload/$payloadApp/info.plist"
    cp -v -p -R "$infoPlist" "$dateDir"
  }
  copyPlist

  cp -v -p -R "$tempFolder/Payload" "$dateDir"
  cp -v -p -R "$toBeSignedFolder/$ogIpa" "$dateDir"
  rm -rf $tempFolder
  rm "$toBeSignedFolder/$ogIpa"
}

##call the functions
ipaCheck
fileCheck "mobileprovision"
fileCheck "dylib"
jsCheck
destinationFolderCheck
getOgIpa
