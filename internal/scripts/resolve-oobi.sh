#!/bin/bash

##################################################################
##                                                              ##
##      Script for resolving OOBIs of other participants        ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

read -p "Type or paste OOBI URL: " -r oobi_url
read -p "Enter an Alias for the AID: " -r alias
echo " "
kli oobi resolve --name "${INT_GAR_NAME}" --passcode "${passcode}" --oobi-alias "${alias}" --oobi "${oobi_url}"
echo " "
kli contacts list --name "${INT_GAR_NAME}" --passcode "${passcode}" | jq "if .alias == \"${alias}\" then \"Alias: \"+.alias+\"\n\rAID:   \"+.id  +\"\n\r\" else \"\" end" --raw-output