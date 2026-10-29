#!/bin/bash
set -eo pipefail

##################################################################
##                                                              ##
##  Ingest a credential exported with export-credential.sh on   ##
##  another GAR's keystore: its issuer KEL, TELs, chained        ##
##  credentials and the credential itself. Use when this        ##
##  keystore lacks a credential the group chains to (e.g. the   ##
##  LE credential behind an OOR/ECR authorization).             ##
##                                                              ##
##  Usage:  import-credential.sh <file.cesr>                    ##
##                                                              ##
##################################################################

PWD=$(pwd)
source "$PWD/source.sh"
set -u

if [ $# -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: import-credential.sh <file.cesr>" >&2
  exit 2
fi
file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

docker run -i --rm \
  --entrypoint python3 \
  -v "${HOME}/.gar":/usr/local/var/keri \
  -v "${INT_GAR_SCRIPT_DIR}":/scripts \
  -v "${INT_GAR_DATA_DIR}":/data \
  -v "${file}":/import/stream.cesr:ro \
  -e PYTHONWARNINGS="ignore::SyntaxWarning" \
  "${KERI_IMAGE}" \
  /scripts/import_credential.py --name "${INT_GAR_NAME}" --passcode "${passcode}" --file /import/stream.cesr
