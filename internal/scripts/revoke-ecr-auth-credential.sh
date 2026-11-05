#!/bin/bash
set -eo pipefail

##################################################################
##                                                              ##
##          Script for revoking ecr auth                        ##
##                                                              ##
##  Revokes in the registry the credential was issued into      ##
##  (its `ri`), looked up in this keystore, not blindly in      ##
##  INT_GAR_REG_NAME: kli builds the rev event in the           ##
##  registry it is given. Stops with the reason if this GAR     ##
##  cannot revoke it (not held, no TEL issuance, already        ##
##  revoked); run ./scripts/sync.sh first.                      ##
##                                                              ##
##################################################################

PWD=$(pwd)
source "$PWD/source.sh"
set -u

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

read -p "Enter the datetime to use: " -r datetime
read -p "Enter the Auth credential SAID: " -r SAID

SAID="$(echo "${SAID}" | tr -d '[:space:]')"
registry="$(docker run -i --rm \
  --entrypoint python3 \
  -v "${HOME}/.gar":/usr/local/var/keri \
  -v "${INT_GAR_SCRIPT_DIR}":/scripts \
  -e PYTHONWARNINGS="ignore::SyntaxWarning" \
  "${KERI_IMAGE}" \
  /scripts/registry_for.py --name "${INT_GAR_NAME}" --passcode "${passcode}" \
    --alias "${INT_GAR_AID_ALIAS}" --registry-name "${INT_GAR_REG_NAME}" --said "${SAID}")" || exit 1

echo "Revoking ${SAID} in registry '${registry}'"
kli vc revoke --name "${INT_GAR_NAME}" --passcode "${passcode}" --alias "${INT_GAR_AID_ALIAS}" --registry-name "${registry}" --said "${SAID}" --time "${datetime}"
