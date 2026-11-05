#!/bin/bash
set -eo pipefail

##################################################################
##                                                              ##
##  Ingest a credential exported with export-credential.sh on   ##
##  another GAR's keystore: its issuer KEL, TELs, chained        ##
##  credentials and the credential itself. Use when this        ##
##  keystore lacks a credential another member holds (e.g. a    ##
##  QVI credential issued without this GAR).                    ##
##                                                              ##
##  Also takes the stream from export-group-credentials.sh,     ##
##  with its manifest (adds any schema this keystore lacks).    ##
##                                                              ##
##  Usage:  import-credential.sh <file.cesr> [manifest.json]    ##
##                                                              ##
##################################################################

PWD=$(pwd)
source "$PWD/source.sh"
set -u

if [ $# -lt 1 ] || [ $# -gt 2 ] || [ ! -f "$1" ] || { [ $# -eq 2 ] && [ ! -f "$2" ]; }; then
  echo "usage: import-credential.sh <file.cesr> [manifest.json]" >&2
  exit 2
fi
file="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
manifest_mount=()
manifest_arg=()
if [ $# -eq 2 ]; then
  manifest_mount=(-v "$(cd "$(dirname "$2")" && pwd)/$(basename "$2")":/import/manifest.json:ro)
  manifest_arg=(--manifest /import/manifest.json)
fi

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

docker run -i --rm \
  --entrypoint python3 \
  -v "${HOME}/.gar":/usr/local/var/keri \
  -v "${EXT_GAR_SCRIPT_DIR}":/scripts \
  -v "${EXT_GAR_DATA_DIR}":/data \
  -v "${file}":/import/stream.cesr:ro \
  ${manifest_mount[@]+"${manifest_mount[@]}"} \
  -e PYTHONWARNINGS="ignore::SyntaxWarning" \
  "${KERI_IMAGE}" \
  /scripts/import_credential.py --name "${EXT_GAR_NAME}" --passcode "${passcode}" --file /import/stream.cesr \
    ${manifest_arg[@]+"${manifest_arg[@]}"}
