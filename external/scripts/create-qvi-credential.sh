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
read -p "Enter the datetime to use: " -r datetime

echo "\"${lei}\"" | jq -f "${EXT_GAR_SCRIPT_DIR}/qvi-data.jq" > "${EXT_GAR_DATA_DIR}/qvi-data.json"

cp "${EXT_GAR_SCRIPT_DIR}/rules.json" "${EXT_GAR_DATA_DIR}/rules.json"

kli vc create \
    --name "${EXT_GAR_NAME}" \
    --passcode "${passcode}" \
    --alias "${EXT_GAR_AID_ALIAS}" \
    --registry-name "${EXT_GAR_REG_NAME}" \
    --schema EBfdlu8R27Fbx-ehrqwImnK-8Cm79sqbAQ4MmvEAYqao \
    --recipient "${recipient}" \
    --data @"/data/qvi-data.json" \
    --rules @"/data/rules.json" \
    --time "${datetime}"
