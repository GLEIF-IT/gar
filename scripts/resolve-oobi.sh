#!/bin/bash

##################################################################
##                                                              ##
##      Script for resolving OOBIs of other participants        ##
##                                                              ##
##################################################################

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

read -p "Type or paste OOBI URL: " -r oobi_url
read -p "Enter an Alias for the AID: " -r alias
echo " "
kli oobi resolve --name "${EXT_GAR_NAME}" --passcode "${passcode}" --oobi-alias "${alias}" --oobi "${oobi_url}"
echo " "
kli contacts list --name "${EXT_GAR_NAME}" --passcode "${passcode}" | jq "if .alias == \"${alias}\" then \"Alias: \"+.alias+\"\nAID:   \"+.id else \"\" end" --raw-output