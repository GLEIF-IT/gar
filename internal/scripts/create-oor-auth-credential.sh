#!/bin/bash

##################################################################
##                                                              ##
##          Script for issuing oor auth                         ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

params="${1:-}"
if [ -n "${params}" ]; then
  # Shared parameters file from prepare-auth-credential.sh: no prompts, identical inputs on every GAR.
  if [ ! -f "${params}" ]; then echo "no such file: ${params}" >&2; exit 2; fi
  if [ "$(jq -r .kind "${params}")" != "oor" ]; then
    echo "${params} is a $(jq -r .kind "${params}") file, not oor" >&2; exit 2
  fi
  le_said=$(jq -r .leSaid "${params}")
  recipient=$(jq -r .recipient "${params}")
  datetime=$(jq -r .createTime "${params}")
  jq .data "${params}" > "${INT_GAR_DATA_DIR}/oor-auth-data.json"
  echo "Creating oor auth credential from ${params}:"
  jq . "${params}"
else
  echo "Use 'kli vc list' to determine the SAID of the legal entity (LE) credential issued to this LE by the QVI"
  read -p "Enter the SAID of the legal entity (LE) credential issued to this LE by the QVI: " -r le_said
  read -p "Enter your LEI : " -r lei
  read -p "Enter or Paste the AID of the recipient of the OOR credential: " -r AID
  read -p "Enter requested person legal name: " -r personLegalName
  read -p "Enter requested official role: " -r officialRole
  read -p "Enter the AID of the QVI to authorize with this AUTH credential: " -r recipient
  read -p "Enter the datetime to use: " -r datetime

  # Prepare DATA Section
  echo "[\"${AID}\", \"${lei}\", \"${personLegalName}\", \"${officialRole}\"]" | jq -f "${INT_GAR_SCRIPT_DIR}/oor-auth-data.jq" > "${INT_GAR_DATA_DIR}/oor-auth-data.json"
fi

# Prepare the EDGES Section
echo "\"${le_said}\"" | jq -f "${INT_GAR_SCRIPT_DIR}/oor-auth-edges-filter.jq" > "${INT_GAR_DATA_DIR}/oor-auth-edge-data.json"
kli saidify --file /data/oor-auth-edge-data.json

# Prepare the RULES section
cp "${INT_GAR_SCRIPT_DIR}/oor-rules.json" "${INT_GAR_DATA_DIR}/oor-rules.json"

kli vc create --name "${INT_GAR_NAME}" --passcode "${passcode}" --alias "${INT_GAR_AID_ALIAS}" --registry-name "${INT_GAR_REG_NAME}" --schema EKA57bKBKxr_kN7iN5i7lMUxpMG-s19dRcmov1iDxz-E --recipient "${recipient}" --data @"/data/oor-auth-data.json" --edges @"/data/oor-auth-edge-data.json" --rules @"/data/oor-rules.json" --time "${datetime}"
