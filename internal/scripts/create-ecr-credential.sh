#!/bin/bash

##################################################################
##                                                              ##
##          Script for issuing ecr credential                   ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

echo "Use 'kli vc list' to determine the SAID of the legal entity (LE) credential issued to this LE by the QVI"
read -p "Enter the SAID of the legal entity (LE) credential issued to this LE by the QVI: " -r le_said
read -p "Enter your LEI : " -r lei
read -p "Enter requested person legal name: " -r personLegalName
read -p "Enter requested engagement context role: " -r engagementContextRole
read -p "Enter the Alias of the recipient: " -r recipient
echo "Do you need to create nonce?"
read -p "[y/N] " -r yn
case $yn in
  "Y" | "y")
    kli nonce
    ;;
  *)
    ;;
esac
echo ""

read -p "Type or paste a nonce: " -r nonce
read -p "Enter the datetime to use: " -r datetime

# Prepare DATA Section
echo "[\"${lei}\", \"${personLegalName}\", \"${engagementContextRole}\"]" | jq -f "${INT_GAR_SCRIPT_DIR}/ecr-data.jq" > "${INT_GAR_DATA_DIR}/ecr-data.json"

# Prepare the EDGES Section
echo "\"${le_said}\"" | jq -f "${INT_GAR_SCRIPT_DIR}/ecr-edges-filter.jq" > "${INT_GAR_DATA_DIR}/ecr-edge-data.json"
kli saidify --file /data/ecr-edge-data.json

# Prepare the RULES section
cp "${INT_GAR_SCRIPT_DIR}/ecr-rules.json" "${INT_GAR_DATA_DIR}/ecr-rules.json"
kli vc create --name "${INT_GAR_NAME}" --passcode "${passcode}" --alias "${INT_GAR_AID_ALIAS}" --registry-name "${INT_GAR_REG_NAME}" --schema EEy9PkikFcANV1l7EHukCeXqrzT1hNZjGlUk7wuMO5jw --recipient "${recipient}" --data @"/data/ecr-data.json" --edges @"/data/ecr-edge-data.json" --rules @"/data/ecr-rules.json"  --time "${datetime}" --private-subject-nonce "${nonce}" --private-credential-nonce "${nonce}" --private
