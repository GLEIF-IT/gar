#!/bin/bash

##################################################################
##                                                              ##
##             Script for creating multisig aid                 ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

read -p "Enter the LEI of the new QVI: " -r lei
read -p "Enter the alias of the new QVI: " -r recipient

echo \"${lei}\" | jq -f "${INT_GAR_SCRIPT_DIR}/qvi-data.jq" > "${INT_GAR_DATA_DIR}/qvi-data.json"

kli vc issue --name "${INT_GAR_NAME}" --passcode "${passcode}" --alias "${INT_GAR_ALIAS}" --registry-name "${INT_GAR_REG_NAME}" --schema EBfdlu8R27Fbx-ehrqwImnK-8Cm79sqbAQ4MmvEAYqao --recipient "${recipient}" --data @"/data/qvi-data.json" --out "/data/credential.json"
