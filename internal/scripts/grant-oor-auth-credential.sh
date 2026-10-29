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
  # Shared parameters file from prepare-auth-credential.sh: the same recipient AID, datetime and credential
  # on every GAR, so every member signs the same grant SAID.
  if [ ! -f "${params}" ]; then echo "no such file: ${params}" >&2; exit 2; fi
  if [ "$(jq -r .kind "${params}")" != "oor" ]; then
    echo "${params} is a $(jq -r .kind "${params}") file, not oor" >&2; exit 2
  fi
  params_abs="$(cd "$(dirname "${params}")" && pwd)/$(basename "${params}")"
  recipient=$(jq -r .recipient "${params}")
  datetime=$(jq -r .grantTime "${params}")
  SAID=$(docker run -i --rm --entrypoint python3 \
           -v "${HOME}/.gar":/usr/local/var/keri -v "${INT_GAR_SCRIPT_DIR}":/scripts \
           -v "${params_abs}":/params.json:ro -e PYTHONWARNINGS="ignore::SyntaxWarning" "${KERI_IMAGE}" \
           /scripts/find_auth_credential.py --name "${INT_GAR_NAME}" --passcode "${passcode}" \
           --alias "${INT_GAR_AID_ALIAS}" --params /params.json) || exit 1
  echo "Granting ${SAID} to ${recipient} with time ${datetime}"
  echo "(non-lead members print nothing more; the lead prints 'grant message sent' once enough members have signed)"
else
  read -p "Enter the AID of the QVI to authorize with this AUTH credential: " -r recipient
  read -p "Enter the datetime to use: " -r datetime
  read -p "Enter the Auth credential SAID: " -r SAID
fi

kli ipex grant --name "${INT_GAR_NAME}" --passcode "${passcode}" --alias "${INT_GAR_AID_ALIAS}" --said "${SAID}" --time "${datetime}" --recipient "${recipient}"
