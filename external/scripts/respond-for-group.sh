#!/bin/bash
set -eo pipefail

##################################################################
##                                                              ##
##  Answer a challenge that was addressed to the GLEIF          ##
##  External AID (the group multisig).                          ##
##                                                              ##
##  Usage:  respond-for-group.sh                                ##
##                                                              ##
##  A group AID cannot sign a challenge response with kli:      ##
##  `kli challenge respond` attaches only this member's         ##
##  signature and the verifier rejects it (see                  ##
##  docs/challenge-response.md). So the response is signed by   ##
##  your MEMBER AID instead. This script first prints the       ##
##  member alias, AID and OOBI the challenger needs, then       ##
##  sends the signed words from that member AID.                ##
##                                                              ##
##################################################################

PWD=$(pwd)
source "$PWD/source.sh"
set -u

if [ "${EXT_GAR_ALIAS}" = "${EXT_GAR_AID_ALIAS}" ]; then
  echo "EXT_GAR_ALIAS is set to the group alias '${EXT_GAR_AID_ALIAS}'." >&2
  echo "A group AID cannot answer a challenge: kli would send a response carrying only your" >&2
  echo "signature and the challenger's verify would never accept it. Point EXT_GAR_ALIAS in" >&2
  echo "~/.gar/external.sh at your member AID alias and run this again." >&2
  exit 1
fi

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

member_aid="$(kli status --name "${EXT_GAR_NAME}" --passcode "${passcode}" --alias "${EXT_GAR_ALIAS}" \
  | tr -d '\r' | awk '/^Identifier:/ {print $2}')"

echo " "
echo "The response will be signed by your MEMBER AID, not by '${EXT_GAR_AID_ALIAS}':"
echo "  alias  ${EXT_GAR_ALIAS}"
echo "  AID    ${member_aid}"
echo " "
echo "Give the challenger this OOBI for the member AID (they must resolve it before verifying):"
kli oobi generate --name "${EXT_GAR_NAME}" --passcode "${passcode}" --alias "${EXT_GAR_ALIAS}" --role witness | tr -d '\r'
echo " "
echo "Tell the challenger to verify with the MEMBER alias as signer, for example:"
echo "  kli challenge verify --generate --out string --alias <their alias> --signer \"${EXT_GAR_ALIAS}\""
echo "Their verify waits up to 300 seconds for this response, so send it while they are waiting."
echo " "

read -p "Type or paste challenge sent to you: " -r words
read -p "Enter the Alias who sent you the words: " -r alias

echo " "
kli challenge respond --name "${EXT_GAR_NAME}" --passcode "${passcode}" --alias "${EXT_GAR_ALIAS}" --words "${words}" --recipient "${alias}"
echo "Challenge phrase signed by '${EXT_GAR_ALIAS}' (${member_aid}) and sent to '${alias}'."
echo "This proves control of your member key behind '${EXT_GAR_AID_ALIAS}', not a group signature."
