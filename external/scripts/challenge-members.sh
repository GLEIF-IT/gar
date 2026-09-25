#!/bin/bash
set -eo pipefail

##################################################################
##                                                              ##
##  Challenge every member of another group (a QVI's QARs or    ##
##  the other GARs) one after another.                          ##
##                                                              ##
##  Usage:  challenge-members.sh <alias> [<alias> ...]          ##
##          challenge-members.sh          (prompts for aliases) ##
##                                                              ##
##  A group AID cannot answer a challenge (see                   ##
##  docs/challenge-response.md), so each member's INDIVIDUAL    ##
##  AID is challenged instead. Each alias must already be a     ##
##  resolved contact (resolve-oobi.sh). For each alias this     ##
##  prints 12 words to send that person privately and waits up  ##
##  to 300 seconds for their signed response. It stops at the   ##
##  first failure. The result is recorded only in this          ##
##  keystore; other GARs must run it themselves.                ##
##                                                              ##
##################################################################

PWD=$(pwd)
source "$PWD/source.sh"
set -u

if [ $# -eq 0 ]; then
  read -p "Enter the contact aliases to challenge, separated by spaces: " -r -a aliases
else
  aliases=("$@")
fi

if [ ${#aliases[@]} -eq 0 ]; then
  echo "usage: $0 <alias> [<alias> ...]" >&2
  exit 1
fi

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

for alias in "${aliases[@]}"; do
  echo " "
  echo "=== Challenging '${alias}' (send the words below to ${alias} only, then wait) ==="
  kli challenge verify --generate --out string --name "${EXT_GAR_NAME}" --passcode "${passcode}" --alias "${EXT_GAR_ALIAS}" --signer "${alias}"
done

echo " "
echo "=== Authenticated state of the challenged contacts ==="
kli contacts list --name "${EXT_GAR_NAME}" --passcode "${passcode}" | tr -d '\r' \
  | jq --argjson names "$(printf '%s\n' "${aliases[@]}" | jq -R . | jq -s .)" \
       'select(.alias as $a | $names | index($a)) | "Alias: "+.alias+"\nAID:   "+.id+"\nAuthenticated: "+(if .challenges | length > 0 then "True" else "False" end)+"\n"' --raw-output
