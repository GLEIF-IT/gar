#!/bin/bash
set -eo pipefail

##################################################################
##                                                              ##
##  Diagnose a group credential issuance (OOR/ECR auth) that    ##
##  is stuck between the GARs: what this keystore holds of the  ##
##  lead's /multisig/iss message, whether `kli multisig join`   ##
##  has a notification to show, the group ixn signature and     ##
##  witness escrows, the credential's escrow and TEL state,     ##
##  and the /multisig mailbox indexes.                          ##
##                                                              ##
##  Usage:  group-issuance-debug.sh                 (read-only) ##
##          group-issuance-debug.sh --said <credential SAID>    ##
##          group-issuance-debug.sh --poll 15                   ##
##            runs the same /multisig mailbox intake that       ##
##            `kli multisig join` uses, then reports. This      ##
##            stores what arrives and creates the notification  ##
##            join needs.                                       ##
##                                                              ##
##  Run it on the GAR that is NOT seeing the credential; on the ##
##  lead it shows the escrows the lead is waiting on.           ##
##                                                              ##
##################################################################

PWD=$(pwd)
source "$PWD/source.sh"
set -u

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

docker run -i --rm \
  --entrypoint python3 \
  -v "${HOME}/.gar":/usr/local/var/keri \
  -v "${INT_GAR_SCRIPT_DIR}":/scripts \
  -v "${INT_GAR_DATA_DIR}":/data \
  -e PYTHONWARNINGS="ignore::SyntaxWarning" \
  "${KERI_IMAGE}" \
  /scripts/group_issuance_debug.py --name "${INT_GAR_NAME}" --passcode "${passcode}" \
    --alias "${INT_GAR_AID_ALIAS}" "$@"
