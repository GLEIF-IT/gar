#!/bin/bash
set -eo pipefail

##################################################################
##                                                              ##
##  List the exchange messages (exns) your AIDs have SENT,      ##
##  such as IPEX credential grants, and what came back.         ##
##                                                              ##
##  Usage:  sent-exns.sh                    (all sent exns)     ##
##          sent-exns.sh --poll 10          (fetch replies 1st) ##
##          sent-exns.sh --route /ipex/grant                    ##
##          sent-exns.sh --alias "GLEIF External AID"           ##
##          sent-exns.sh --received         (incoming too)      ##
##          sent-exns.sh --verbose          (full JSON bodies)  ##
##          sent-exns.sh --json [...]       (records for jq)    ##
##                                                              ##
##  A sent exn lives in the RECIPIENT's mailbox, which nobody   ##
##  else can read, so this shows your keystore's own record of  ##
##  every exn it fully signed (for the group AID: every grant   ##
##  the members completed) and, per grant, the credential and   ##
##  its registry state, which members signed, who delivered it, ##
##  and the admit if one arrived. --poll checks your mailboxes  ##
##  first, on the same topics `kli ipex list --poll` uses.      ##
##                                                              ##
##################################################################

PWD=$(pwd)
source "$PWD/source.sh"
set -u

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

# No tty: this script never prompts, and a docker pty rewrites newlines and can
# garble or cut off large outputs such as --json --verbose. Output is a plain
# byte stream, safe to pipe into jq or redirect to a file.
docker run -i --rm \
  --entrypoint python3 \
  -v "${HOME}/.gar":/usr/local/var/keri \
  -v "${EXT_GAR_SCRIPT_DIR}":/scripts \
  -v "${EXT_GAR_DATA_DIR}":/data \
  -e PYTHONWARNINGS="ignore::SyntaxWarning" \
  "${KERI_IMAGE}" \
  /scripts/sent_exns.py --name "${EXT_GAR_NAME}" --passcode "${passcode}" "$@"
