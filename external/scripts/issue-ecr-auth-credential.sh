#!/bin/bash

##################################################################
##                                                              ##
##          Script for issuing ecr auth                         ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

read -p "Enter your LEI : " -r lei
read -p "Enter requested person legal name: " -r personLegalName
read -p "Enter requested engagement context role: " -r engagementContextRole

echo \'[\"${lei}\", \"${personLegalName}\", \"${engagementContextRole}\"]\' | jq -f "${EXT_GAR_SCRIPT_DIR}/ecr-auth-data.jq" > "${EXT_GAR_DATA_DIR}/ecr-auth-data.json"

read -p "Enter AID of QVI : " -r qvi

echo \"${qvi}\" | jq -f "${EXT_GAR_SCRIPT_DIR}/ecr-auth-edge-data.jq" > "${EXT_GAR_DATA_DIR}/ecr-auth-edge-data.json"

# wip
kli vc issue --name "${EXT_GAR_NAME}" --passcode "${passcode}" --alias "${EXT_GAR_ALIAS}" --registry-name "${EXT_GAR_REG_NAME}" --schema ED_PcIn1wFDe0GB0W7Bk9I4Q_c9bQJZCM2w7Ex9Plsta --recipient "${recipient}" --data @"${EXT_GAR_DATA_DIR}/ecr-auth-data.json"
