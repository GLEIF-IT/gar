#!/bin/bash

##################################################################
##                                                              ##
##          Script for issuing oor auth                         ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

read -p "Enter your LEI : " -r lei
read -p "Enter requested person legal name: " -r personLegalName
read -p "Enter requested official role: " -r officialRole

echo \'[\"${lei}\", \"${personLegalName}\", \"${officialRole}\"]\' | jq -f "${EXT_GAR_SCRIPT_DIR}/oor-auth-data.jq" > "${EXT_GAR_DATA_DIR}/oor-auth-data.json"

read -p "Enter AID of QVI : " -r qvi

echo \"${qvi}\" | jq -f "${EXT_GAR_SCRIPT_DIR}/oor-auth-edge-data.jq" > "${EXT_GAR_DATA_DIR}/oor-auth-edge-data.json"

# wip
kli vc issue --name "${EXT_GAR_NAME}" --passcode "${passcode}" --alias "${EXT_GAR_ALIAS}" --registry-name "${EXT_GAR_REG_NAME}" --schema EDqjl80uP0r_SNSp-yImpLGglTEbOwgO77wsOPjyRVKy --recipient "${recipient}" --data @"${EXT_GAR_DATA_DIR}/oor-auth-data.json"
