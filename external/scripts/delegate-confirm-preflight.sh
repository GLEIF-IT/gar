#!/bin/bash
set -eo pipefail

##################################################################
##                                                              ##
##  Read-only preflight before approving a QVI rotation with    ##
##  `kli delegate confirm`. Run it before the call.             ##
##                                                              ##
##  Usage:  delegate-confirm-preflight.sh                       ##
##          delegate-confirm-preflight.sh --delegate <QVI AID>  ##
##                                                              ##
##  Checks that this keystore holds the QVI's current key       ##
##  state (without it the rotation never shows up in confirm),  ##
##  lists anything already in escrow, checks the External       ##
##  witness answers, and shows the seal in scripts/anchor.json. ##
##                                                              ##
##################################################################

PWD=$(pwd)
source "$PWD/source.sh"
set -u

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

docker run -it --rm \
  --entrypoint python3 \
  -v "${HOME}/.gar":/usr/local/var/keri \
  -v "${EXT_GAR_SCRIPT_DIR}":/scripts \
  -v "${EXT_GAR_DATA_DIR}":/data \
  -e PYTHONWARNINGS="ignore::SyntaxWarning" \
  "${KERI_IMAGE}" \
  /scripts/delegate_confirm_preflight.py --name "${EXT_GAR_NAME}" --passcode "${passcode}" \
    --alias "${EXT_GAR_AID_ALIAS}" "$@" \
  | tr -d '\r'
