#!/bin/bash

##################################################################
##                                                              ##
##             Script for creating multisig aid                 ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

read -p "Enter the LEI of the new QVI: " -r lei
read -p "Enter the alias of the new QVI: " -r recipient

echo \"${lei}\" | jq -f "${EXT_GAR_SCRIPT_DIR}/qvi-data.jq" > "${EXT_GAR_DATA_DIR}/qvi-data.json"

kli vc issue --name "${EXT_GAR_NAME}" --passcode "${passcode}" --alias "${EXT_GAR_ALIAS}" --registry-name "${EXT_GAR_REG_NAME}" --schema ELqriXX1-lbV9zgXP4BXxqJlpZTgFchll3cyjaCyVKiz --recipient "${recipient}" --data @"${EXT_GAR_DATA_DIR}/qvi-data.json"
