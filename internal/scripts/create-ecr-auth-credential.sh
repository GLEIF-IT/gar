#!/bin/bash

##################################################################
##                                                              ##
##          Script for issuing ecr auth                         ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

read -p "Enter your LEI : " -r lei
read -p "Enter or Paste the AID of the recipient of the ECR credential: " -r AID
read -p "Enter requested person legal name: " -r personLegalName
read -p "Enter requested engagement context role: " -r engagementContextRole
read -p "Enter the Alias of the QVI to authorize with this AUTH credential: " -r recipient
read -p "Enter the datetime to use: " -r datetime

# Prepare DATA Section
echo "[\"${AID}\", \"${lei}\", \"${personLegalName}\", \"${engagementContextRole}\"]" | jq -f "${INT_GAR_SCRIPT_DIR}/ecr-auth-data.jq" > "${INT_GAR_DATA_DIR}/ecr-auth-data.json"

# Prepare the EDGES Section
le_said=EB9yGbWXOn_MhTQsHltftAsNrlWAxgedMPIQl4rg6C1e

echo "\"${le_said}\"" | jq -f "${INT_GAR_SCRIPT_DIR}/ecr-auth-edges-filter.jq" > "${INT_GAR_DATA_DIR}/ecr-auth-edge-data.json"
kli saidify --file /data/ecr-auth-edge-data.json

# Prepare the RULES section
cp "${INT_GAR_SCRIPT_DIR}/ecr-rules.json" "${INT_GAR_DATA_DIR}/ecr-rules.json"

kli vc create --name "${INT_GAR_NAME}" --passcode "${passcode}" --alias "${INT_GAR_AID_ALIAS}" --registry-name "${INT_GAR_REG_NAME}" --schema EH6ekLjSr8V32WyFbGe1zXjTzFs9PkTYmupJ9H65O14g --recipient "${recipient}" --data @"/data/ecr-auth-data.json" --edges @"/data/ecr-auth-edge-data.json" --rules @"/data/ecr-rules.json"  --time "${datetime}"
