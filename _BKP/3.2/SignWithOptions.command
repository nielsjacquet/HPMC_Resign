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

##Paths & Variables
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"    ##Homedir
resourcesPath="$DIR/Resources"                                        ##path to the resource folder
sharedResourcesPath="$DIR/../_SharedResources/"                       ##Path to the shared resource folder
configDotPlistFolder="$DIR/../_SharedResources/ConfigPlists"
fixDate=$(date +"%Y%m%d - %Hh%M")                                   ##Block the date and hour for folder creation
resourcesPath="$DIR/Resources"                                      ##path to the resource folder
sharedResourcesProvisioningPath="$DIR/../_SharedResources/ProvisioningProfile"
codesign="GZ75RPKBFF"                                               ##the developer certificate
iosJsPath="$DIR/Resources/ios"                                      ##path to the jsfolder
entitlements="$DIR/_TEMP/entitlements.txt"                          ##temp path used for the entitlements
toBeSignedFolder="$DIR/ToBeSigned"                                  ##path for the ipas that needs to signed
tempFolder="$DIR/_TEMP"                                             ##Temp folder for extract the ipa etc
payloadFolder="$tempFolder/Payload"                                 ##payloadFolder
extractFile="$DIR/test.txt"                                         ##used for the extraction of the devices in the provisioningProfile
LC_ALL=C
echo $DIR
function startQuestions {

  printf "${GREEN}Do you need a config.plist swap Y(es) / N(o)${NC}\n"
  read -n1 customConfig
  BR
  if [[ $customConfig = "Y" ]] | [[ $customConfig = "y" ]]
   then
    customConfig=1
  fi
  if [[ $customConfig = "N" ]] | [[ $customConfig = "n" ]]
   then
    customConfig=0
  fi

  printf "${GREEN}Do you need the original entitlements?${NC}\n"
  read -n1 customEntitlements
  BR
  if [[ $customEntitlements = "Y" ]] | [[ $customEntitlements = "y" ]]
   then
    customEntitlements=1
  fi
  if [[ $customEntitlements = "N" ]] | [[ $customEntitlements = "n" ]]
   then
    customEntitlements=0
  fi

  printf "${YELLOW} ----------------------\n"
  printf "${YELLOW}| ${RED}DEBUGINFO${YELLOW}            |\n"
  printf "| customConfig: $customConfig      |\n"
  printf "| customEntitlements: $customEntitlements|\n"
  printf "${YELLOW} ----------------------${NC}\n"

  readPlist
}

function readPlist {
  case $customConfig in
    1)
    for configPlists in "$configDotPlistFolder"/*
      do
        configname=$(basename $configPlists )
        configFileNameArray+=("$configname")
        configPathArray+=("$configPlists")
      done
    configFileNameArrayLength=${#configFileNameArray[@]}
    choosePlist
      ;;
    0)
    echo no config.plist needed
    ipaCheck
      ;;
  esac
}

function choosePlist {
  for (( i = 0; i < $configFileNameArrayLength; i++ ))
    do
      echo "[$i]" ${configFileNameArray[$i]}
    done
  printf "${GREEN}Please enter the needed Config.plist${NC}\n"
  read configAnswer
  cat ${configPathArray[$configAnswer]}
  correctList
}

function correctList {
  printf "${GREEN}Is this the correct one?${NC}\n"
  printf "${YELLOW}Choose Y(es) or N(o)${NC}\n"
  read -n1 correctConfig
  if [[ $correctConfig = "Y" ]] | [[ $correctConfig = "y" ]]
   then
    echo "YES"
    ipaCheck
  fi

  if [[ $correctConfig = "N" ]] | [[ $correctConfig = "n" ]]
   then
    Echo "NO"
    choosePlist
  fi
}

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
  provisionCheck
  }

##allround function to check the files in the resource folder. Use fileCheck "extention"
function provisionCheck {
  cd $sharedResourcesProvisioningPath
  echo $sharedResourcesProvisioningPath
  amountOfprofiles=$(ls | grep -c ".mobileprovision")
  echo amountOfprofiles: $amountOfprofiles
  if [[ $amountOfprofiles != 1 ]]
    then
      printf "${RED}There is an issue with the mobileprovision file, please go to the $sharedResourcesPath folder!${NC}\n"
      exit 113
    else
      profiledot=$(ls | grep ".mobileprovision")
      echo profiledot: $profiledot
      provisioningProfilePath="$sharedResourcesProvisioningPath/$profiledot"
      echo provisioningProfilePath: $sharedResourcesProvisioningPath
  fi
  dylibCheck
}

function dylibCheck {
    cd $resourcesPath
    amountOfdylibs=$(ls | grep -c ".dylib")
    echo amountOfdylibs: $amountOfdylibs
    if [[ $amountOfdylibs != 1 ]]
      then
        printf "${RED}There is an issue with the dylib file, please go to the $resourcesPath folder!${NC}\n"
        exit 113
      else
        dylibdotlyb=$(ls | grep ".dylib")
        echo dylibdotlyb: $dylibdotlyb
        dylib="$resourcesPath/$dylibdotlyb"
        echo dylib: $dylib
    fi
    jsCheck
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
  destinationFolderCheck
  getOgIpa
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
  #LC_ALL=C sed -i '' 's/<key>aps-environment<\/key>//g' $entitlements
  #LC_ALL=C sed -i '' 's/<string>production<\/string>/<string>development<\/string>/g' $entitlements
  LC_ALL=C sed -i '' 's/<key>aps-environment<\/key>//g' $entitlements
  LC_ALL=C sed -i '' 's/<string>production<\/string>//g' $entitlements
  cat $entitlements
  printf "${NC}\n"                          ## set the get-task-allow to true
  copyConfigPlist
}

#copy the config.plist in the appfolder
function copyConfigPlist {
  printf "${GREEN}Copy the plist${NC}\n"
  cd $payloadFolder
  payloadApp=$(ls | grep '.app')
  printf "${RED}DEBUGGING copyPlist payloadApp: $payloadApp ${NC}\n"
  cd "$payloadFolder/$payloadApp"
  cp -v ${configPathArray[$configAnswer]} "$payloadFolder/$payloadApp/Config.plist"
  extractVersion
}

#extract the version from the info.plist
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

#extrat the bundleID from info.plist
function extractBundleID {                                                      ##extract the app bundleID for naming sceme
  printf "${GREEN}Extracting the bundle id${NC}\n"
  bundleIDRude=$(cat $infoPlist | grep -A1 "CFBundleIdentifier")
  echo bundleIDRude: $bundleIDRude
  bundleIDMinEnd=$(echo ${bundleIDRude%?????????})
  echo bundleIDMinEnd: $bundleIDMinEnd
  bundleIDMinFront=$(echo ${bundleIDMinEnd:38})
  echo bundleIDMinFront: $bundleIDMinFront
  bundleID=$bundleIDMinFront
  zipIpa
}

#zip the payloadFolder to .ipa
function zipIpa {
  printf "${GREEN}Zipping the payloadFolder${NC}\n"
  cd $payloadFolder
  echo payloadFolder $payloadFolder
  find . -name ".DS_Store" -exec rm -rf {} +;
  cd $tempFolder
  printf "${GREEN} ogipaname: $ogIpa ${NC}\n"
  zip -r "$ogIpa" ./Payload
  getNewZippedIpa
}

#get the name from the new zipped ipa
function getNewZippedIpa {
printf "${GREEN}Greabbing the new and edited ipa${NC}\n"
cd $tempFolder
newZippedIpa=$(ls | grep '.ipa')
printf "${RED}DEBUGGING getNewZippedIpa: $newZippedIpa ${NC}\n"
signHPMC
}

##sign with HPMC module
function signHPMC {
  printf "${GREEN}signing the app${NC}\n"
  cd $resourcesPath
  printf "${YELLOW}OGIPA: $toBeSignedFolder/$ogIpa\n"
  printf "dylib: $dylib\n"
  printf "codesign: $codesign\n"
  printf "provisioningProfile: $provisioningProfilePath\n"
  printf "iosJsPath: $iosJsPath\n"
  printf "destinationFolder: $destinationFolder\n"
  printf "entitlements: $entitlements${NC}\n"
  ipaName=$bundleID"_"$buildVersion"_HPMC-Enabled.ipa"
  echo "new zipped ipa: $newZippedIpa"
  echo "orginal ipa path = $toBeSignedFolder/$ogIpa"
  echo "newipaName = $ipaName"
  ##sign with the original app entitlements
  #./HPMCEnabler "$toBeSignedFolder/$ogIpa" -inject $dylib -codesign $codesign -p $provisioningProfilePath -j $iosJsPath -e $entitlements -v -d "$destinationFolder"
  ##sign and Rename ipa file
  ./HPMCEnabler "$tempFolder/$newZippedIpa" -inject $dylib -codesign $codesign -p $provisioningProfilePath -j $iosJsPath -e $entitlements -n "$ipaName" -v -d "$destinationFolder"
  #./HPMCEnabler "$toBeSignedFolder/$ogIpa" -inject $dylib -codesign $codesign -p $provisioningProfilePath -j $iosJsPath -e $entitlements -v -d "$destinationFolder"

  ##sign with original HPMC entitlements
  #./HPMCEnabler "$toBeSignedFolder/$ogIpa" -inject $dylib -codesign $codesign -p $provisioningProfilePath -j $iosJsPath -v -d "$destinationFolder"

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
startQuestions
