#!/bin/bash
set -eo pipefail

##################################################################
##                                                              ##
##  Compare your contacts with the credentials the GLEIF        ##
##  Internal AID has issued: for each contact, the credentials  ##
##  issued to it (issuee) or about it (person AID), their       ##
##  registry state, and whether the IPEX grant was sent and     ##
##  admitted. Issued credentials that name no contact are       ##
##  listed at the end.                                          ##
##                                                              ##
##  Usage:  contacts-credentials.sh                             ##
##          contacts-credentials.sh --poll 10   (fetch admits)  ##
##          contacts-credentials.sh --contact "Some QVI"        ##
##          contacts-credentials.sh --skip-empty                ##
##          contacts-credentials.sh --json [...] (for jq)       ##
##                                                              ##
##################################################################

PWD=$(pwd)
source "$PWD/source.sh"
set -u

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

# No tty: never prompts, and the output is a plain byte stream safe for jq.
docker run -i --rm \
  --entrypoint python3 \
  -v "${HOME}/.gar":/usr/local/var/keri \
  -v "${INT_GAR_SCRIPT_DIR}":/scripts \
  -v "${INT_GAR_DATA_DIR}":/data \
  -e PYTHONWARNINGS="ignore::SyntaxWarning" \
  "${KERI_IMAGE}" \
  /scripts/contacts_credentials.py --name "${INT_GAR_NAME}" --passcode "${passcode}" \
    --alias "${INT_GAR_AID_ALIAS}" "$@"
