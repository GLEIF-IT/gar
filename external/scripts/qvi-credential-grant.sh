#!/bin/bash

##################################################################
##                                                              ##
##             Script for IPEX granting QVI credential          ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

params="${1:-}"
if [ -n "${params}" ]; then
  # Shared parameters file from prepare-qvi-credential.sh: the same recipient AID, datetime and credential
  # on every GAR, so every member signs the same grant SAID.
  if [ ! -f "${params}" ]; then echo "no such file: ${params}" >&2; exit 2; fi
  if [ "$(jq -r .kind "${params}")" != "qvi" ]; then
    echo "${params} is a $(jq -r .kind "${params}") file, not qvi" >&2; exit 2
  fi
  params_abs="$(cd "$(dirname "${params}")" && pwd)/$(basename "${params}")"
  recipient=$(jq -r .recipient "${params}")
  datetime=$(jq -r .grantTime "${params}")
  SAID=$(docker run -i --rm --entrypoint python3 \
           -v "${HOME}/.gar":/usr/local/var/keri -v "${EXT_GAR_SCRIPT_DIR}":/scripts \
           -v "${params_abs}":/params.json:ro -e PYTHONWARNINGS="ignore::SyntaxWarning" "${KERI_IMAGE}" \
           /scripts/find_qvi_credential.py --name "${EXT_GAR_NAME}" --passcode "${passcode}" \
           --alias "${EXT_GAR_AID_ALIAS}" --params /params.json) || exit 1
  echo "Granting ${SAID} to ${recipient} with time ${datetime}"
  echo "(non-lead members print nothing more; the lead prints 'grant message sent' once enough members have signed)"
else
  read -p "Enter the SAID of the new QVI credential: " -r SAID
  read -p "Enter the alias of the new QVI: " -r recipient
  read -p "Enter the datetime to use: " -r datetime
fi

kli ipex grant \
    --name "${EXT_GAR_NAME}" \
    --passcode "${passcode}" \
    --alias "${EXT_GAR_AID_ALIAS}" \
    --said "${SAID}" \
    --recipient "${recipient}" \
    --time "${datetime}"
