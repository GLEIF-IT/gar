#!/bin/bash
set -euo pipefail

##################################################################
##                                                              ##
##  Diagnose why a mailbox message is not being accepted.       ##
##                                                              ##
##  Usage:  exn-probe.sh <file>                                 ##
##                                                              ##
##  <file> holds one raw message exactly as printed by          ##
##  mailbox-debug.sh --verbose (JSON body followed by its CESR  ##
##  attachments). It is run through the same parser and         ##
##  handlers `kli challenge verify` uses, against the real       ##
##  keystore, with keripy logging on. If accepted, it is stored ##
##  just as if the mailbox poller had received it.              ##
##                                                              ##
##################################################################

PWD=$(pwd)
source "$PWD/source.sh"

if [ $# -lt 1 ] || [ ! -f "$1" ]; then
  echo "usage: $0 <message file>" >&2
  exit 1
fi

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

# The container only sees the mounted data directory, so stage the file there.
cp "$1" "${EXT_GAR_DATA_DIR}/.probe-message"
trap 'rm -f "${EXT_GAR_DATA_DIR}/.probe-message"' EXIT

docker run -it --rm \
  --entrypoint python3 \
  -v "${HOME}/.gar":/usr/local/var/keri \
  -v "${EXT_GAR_SCRIPT_DIR}":/scripts \
  -v "${EXT_GAR_DATA_DIR}":/data \
  -e PYTHONWARNINGS="ignore::SyntaxWarning" \
  "${KERI_IMAGE}" \
  /scripts/exn_probe.py --name "${EXT_GAR_NAME}" --passcode "${passcode}" --file /data/.probe-message "${@:2}" \
  | tr -d '\r'
