#!/bin/bash
set -eo pipefail

##################################################################
##                                                              ##
##  Prepare anchor.json for a MANUAL delegation approval.       ##
##                                                              ##
##  Usage:  anchor-seal.sh <delegate AID> <hex sn> <event SAID> ##
##          anchor-seal.sh ... --force   (event not held here)  ##
##                                                              ##
##  Validates the three values confirmed with the QARs on the   ##
##  call, checks the event in the local keystore, prints the    ##
##  same key-change summary `kli delegate confirm` shows, and   ##
##  writes scripts/anchor.json. Then run multisig-interact.sh.  ##
##                                                              ##
##################################################################

if [ $# -lt 3 ]; then
  echo "usage: $0 <delegate AID> <hex sequence number> <event SAID> [--force]" >&2
  exit 1
fi
aid="$1"; sn="$2"; said="$3"; shift 3

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
  /scripts/anchor_seal.py --name "${EXT_GAR_NAME}" --passcode "${passcode}" \
    -i "${aid}" -s "${sn}" -d "${said}" --out /scripts/anchor.json "$@" \
  | tr -d '\r'
