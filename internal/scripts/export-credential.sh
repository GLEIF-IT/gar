#!/bin/bash
set -eo pipefail

##################################################################
##                                                              ##
##  Export a credential this keystore holds, with its issuer    ##
##  KEL, TELs and full chain, as one CESR stream another GAR    ##
##  can ingest with import-credential.sh.                       ##
##                                                              ##
##  Usage:  export-credential.sh <credential SAID> [out.cesr]   ##
##                                                              ##
##################################################################

PWD=$(pwd)
source "$PWD/source.sh"
set -u

if [ $# -lt 1 ]; then
  echo "usage: export-credential.sh <credential SAID> [out.cesr]" >&2
  exit 2
fi
said="$1"
out="${2:-${said}.cesr}"

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

docker run -i --rm \
  -v "${HOME}/.gar":/usr/local/var/keri \
  -e PYTHONWARNINGS="ignore::SyntaxWarning" \
  "${KERI_IMAGE}" \
  vc export --name "${INT_GAR_NAME}" --passcode "${passcode}" --alias "${INT_GAR_AID_ALIAS}" \
    --said "${said}" --full | tr -d '\r' > "${out}"

echo "wrote $(wc -c < "${out}") bytes to ${out}; send this file to the other GAR"
