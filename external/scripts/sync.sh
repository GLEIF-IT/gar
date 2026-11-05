#!/bin/bash
set -eo pipefail

##################################################################
##                                                              ##
##  Catch up with the rest of the group. Run at the start of    ##
##  every session, after `source ./source.sh`.                  ##
##                                                              ##
##    pull    poll this GAR's mailboxes for group credentials   ##
##            other members pushed (with TELs, chains, KELs)    ##
##    adopt   register the group's existing registry if this    ##
##            GAR has none yet (GARs that joined later)         ##
##    push    send every other member the group credentials     ##
##            they have not been sent yet, via their witnesses  ##
##    report  what this GAR can revoke now                      ##
##                                                              ##
##  Usage:  sync.sh                  pull, adopt, push, report  ##
##          sync.sh --dry-run        show what push would send  ##
##          sync.sh --poll 60        poll longer (default 20s)  ##
##          sync.sh --no-push | --no-pull | --full              ##
##          sync.sh --to <member AID>   push to one member only ##
##                                                              ##
##################################################################

PWD=$(pwd)
source "$PWD/source.sh"
set -u

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

docker run -i --rm \
  --entrypoint python3 \
  -v "${HOME}/.gar":/usr/local/var/keri \
  -v "${EXT_GAR_SCRIPT_DIR}":/scripts \
  -e PYTHONWARNINGS="ignore::SyntaxWarning" \
  "${KERI_IMAGE}" \
  /scripts/sync.py --name "${EXT_GAR_NAME}" --passcode "${passcode}" \
    --alias "${EXT_GAR_AID_ALIAS}" --registry-name "${EXT_GAR_REG_NAME}" "$@"
