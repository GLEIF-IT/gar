#!/bin/bash
set -eo pipefail

##################################################################
##                                                              ##
##  List the credentials the GLEIF Internal AID has created     ##
##  (issued into its registry) but not yet granted: no IPEX     ##
##  grant for the credential was completed by this keystore.    ##
##  These are the ones still waiting for a grant-*.sh run.      ##
##                                                              ##
##  Usage:  ungranted-credentials.sh                            ##
##          ungranted-credentials.sh --poll 10                  ##
##          ungranted-credentials.sh --json      (for jq)       ##
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
  /scripts/ungranted_credentials.py --name "${INT_GAR_NAME}" --passcode "${passcode}" \
    --alias "${INT_GAR_AID_ALIAS}" "$@"
