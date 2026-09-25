#!/bin/bash

##################################################################
##                                                              ##
##      Script for resolving OOBIs of other participants        ##
##                                                              ##
##  Pass --force to re-fetch an OOBI resolved before; without   ##
##  it kli skips the URL and any KEL it serves is not loaded.   ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

read -p "Type or paste OOBI URL: " -r oobi_url
read -p "Enter an Alias for the AID: " -r alias
echo " "

if [ -z "$alias" ]
then
  kli oobi resolve --name "${EXT_GAR_NAME}" --passcode "${passcode}" --oobi "${oobi_url}" "$@"
else
  kli oobi resolve --name "${EXT_GAR_NAME}" --passcode "${passcode}" --oobi-alias "${alias}" --oobi "${oobi_url}" "$@"
  echo " "
  kli contacts list --name "${EXT_GAR_NAME}" --passcode "${passcode}" | jq "if .alias == \"${alias}\" then \"Alias: \"+.alias+\"\n\rAID:   \"+.id  +\"\n\r\" else \"\" end" --raw-output
fi

