#!/bin/bash
set -eo pipefail

##################################################################
##                                                              ##
##  Register the group's EXISTING credential registry in this   ##
##  keystore under INT_GAR_REG_NAME, for a GAR that was not     ##
##  part of the registry inception (e.g. joined the group       ##
##  later). Do not run create-registry.sh for this: a new       ##
##  registry cannot hold or revoke the group's credentials.     ##
##                                                              ##
##  Writes one local record; signs and sends nothing. Run       ##
##  import-credential.sh with the export-group-credentials.sh   ##
##  stream first, so the registry's TEL is here.                ##
##                                                              ##
##  Usage:  adopt-registry.sh <manifest.json>                   ##
##          adopt-registry.sh --regk <registry prefix>          ##
##                                                              ##
##################################################################

PWD=$(pwd)
source "$PWD/source.sh"
set -u

mounts=()
case "${1:-}" in
  --regk)
    [ $# -eq 2 ] || { echo "usage: adopt-registry.sh <manifest.json> | --regk <registry prefix>" >&2; exit 2; }
    sel=(--regk "$2")
    ;;
  *)
    if [ $# -ne 1 ] || [ ! -f "$1" ]; then
      echo "usage: adopt-registry.sh <manifest.json> | --regk <registry prefix>" >&2
      exit 2
    fi
    mounts=(-v "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")":/import/manifest.json:ro)
    sel=(--manifest /import/manifest.json)
    ;;
esac

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

docker run -i --rm \
  --entrypoint python3 \
  -v "${HOME}/.gar":/usr/local/var/keri \
  -v "${INT_GAR_SCRIPT_DIR}":/scripts \
  ${mounts[@]+"${mounts[@]}"} \
  -e PYTHONWARNINGS="ignore::SyntaxWarning" \
  "${KERI_IMAGE}" \
  /scripts/adopt_registry.py --name "${INT_GAR_NAME}" --passcode "${passcode}" \
    --alias "${INT_GAR_AID_ALIAS}" --registry-name "${INT_GAR_REG_NAME}" "${sel[@]}"
