#!/bin/bash

##################################################################
##                                                              ##
##          Script for listing credentials issued by            ##
##          Internal GAR filtered by issuee AID                 ##
##                                                              ##
##  Usage: list-credentials-issued.sh <issuee AID> [kli args]   ##
##                                                              ##
##  Prints one JSON object per matching credential:             ##
##    {"status": "Issued"|"Revoked"|"Unknown", "credential": {..}}   ##
##                                                              ##
##  `kli vc list` has no JSON output mode; its --verbose form   ##
##  prints each credential's JSON with a leading tab, which is  ##
##  what gets extracted here.                                   ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

if [ -z "$1" ]; then
    echo "Usage: $0 <issuee_AID>"
    echo "  Lists credentials issued by Internal GAR to the specified issuee AID"
    exit 1
fi

issuee="$1"
shift

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

kli vc list \
    --name "${INT_GAR_NAME}" \
    --passcode "${passcode}" \
    --alias "${INT_GAR_AID_ALIAS}" \
    --issued \
    --verbose \
    --poll "$@" \
    | tr -d '\r' \
    | sed 's/\x1b\[[0-9;]*m//g' \
    | awk '
        # Each credential block: "Credential #n: <said>", "    Status: <word> ...",
        # "    Full Credential:", then the JSON lines each prefixed with a tab.
        /^Credential #/        { if (injson) { print "}"; injson = 0 } status = "Unknown"; next }
        /^    Status: /        { status = $2; next }
        /^    Full Credential:/ { printf "{\"status\":\"%s\",\"credential\":\n", status; injson = 1; next }
        injson && /^\t/        { sub(/^\t/, ""); print; next }
        injson                 { print "}"; injson = 0 }
        END                    { if (injson) print "}" }
      ' \
    | jq -c --arg aid "${issuee}" 'select(.credential.a.AID == $aid)'
