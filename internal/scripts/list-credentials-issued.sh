#!/bin/bash

##################################################################
##                                                              ##
##  List credentials issued by the Internal GAR to one issuee,  ##
##  with the SAID of each credential and of the IPEX grant      ##
##  message that delivered it.                                  ##
##                                                              ##
##  Usage: list-credentials-issued.sh <issuee AID> [--json]     ##
##                                                              ##
##  Neither `kli vc list` nor `kli ipex list` has a JSON output ##
##  mode, so this parses their --verbose / text output: the    ##
##  credential JSON is printed tab-indented, and each sent      ##
##  grant is printed as "GRANT - SAID: <said>" followed by      ##
##  "Credential <said>:".                                       ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

if [ -z "$1" ]; then
    echo "Usage: $0 <issuee_AID> [--json]"
    echo "  Lists credentials issued by Internal GAR to the specified issuee AID,"
    echo "  with the credential SAID and the SAID of the IPEX grant that delivered it."
    exit 1
fi

issuee="$1"
shift
json=false
if [ "${1:-}" = "--json" ]; then json=true; shift; fi

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

# Strip the Docker tty carriage returns and kli's colour codes.
clean() { tr -d '\r' | sed 's/\x1b\[[0-9;]*m//g'; }

# `kli vc list --verbose` text -> stream of {"status":..., "credential": {...}}
parse_credentials() {
    awk '
        /^Credential #/        { if (injson) { print "}"; injson = 0 } status = "Unknown"; next }
        /^    Status: /        { status = $2; next }
        /^    Full Credential:/ { printf "{\"status\":\"%s\",\"credential\":\n", status; injson = 1; next }
        injson && /^\t/        { sub(/^\t/, ""); print; next }
        injson                 { print "}"; injson = 0 }
        END                    { if (injson) print "}" }'
}

# `kli ipex list --sent --type grant` text -> {"<credential said>": [{"grant":..., "response":...}, ...]}
parse_grants() {
    awk '
        function flush() { if (grant != "") print cred, grant, resp; grant = ""; cred = ""; resp = "" }
        /^GRANT - SAID: /      { flush(); grant = $4; next }
        /^Credential .*:$/     { cred = $2; sub(/:$/, "", cred); next }
        /^    Response: /      { resp = $2 " " $3; gsub(/[()]/, "", resp); next }
        END                    { flush() }' \
    | jq -R -s '
        [ split("\n")[] | select(length > 0) | split(" ")
          | {cred: .[0], grant: .[1], response: (if .[2] != "" and .[2] != null then (.[2] + " " + .[3]) else null end)} ]
        | group_by(.cred) | map({key: .[0].cred, value: map({grant, response})}) | from_entries'
}

creds=$(kli vc list --name "${INT_GAR_NAME}" --passcode "${passcode}" --alias "${INT_GAR_AID_ALIAS}" \
            --issued --verbose --poll "$@" | clean | parse_credentials)
grants=$(kli ipex list --name "${INT_GAR_NAME}" --passcode "${passcode}" --alias "${INT_GAR_AID_ALIAS}" \
            --sent --type grant | clean | parse_grants)
[ -n "${grants}" ] || grants='{}'

if [ "${json}" = true ]; then
    printf '%s' "${creds}" | jq -c --arg aid "${issuee}" --argjson grants "${grants}" \
        'select(.credential.a.AID == $aid) | . + {grants: ($grants[.credential.d] // [])}'
    exit 0
fi

if [ -t 1 ]; then B=$'\033[1m'; C=$'\033[36m'; Y=$'\033[33m'; N=$'\033[0m'; else B=""; C=""; Y=""; N=""; fi

printf '%s' "${creds}" | jq -r --arg aid "${issuee}" --argjson grants "${grants}" \
    --arg B "$B" --arg C "$C" --arg Y "$Y" --arg N "$N" '
    select(.credential.a.AID == $aid)
    | .credential as $c | ($grants[$c.d] // []) as $g
    | "\($B)Credential SAID:\($N) \($C)\($B)\($c.d)\($N)   [\(.status)]",
      "    \($c.a.personLegalName // "-")  |  \($c.a.engagementContextRole // $c.a.officialRole // "-")  |  LEI \($c.a.LEI // "-")  |  issued \($c.a.dt // "-")",
      (if ($g | length) == 0
       then "    \($B)Grant SAID:\($N)      \($Y)(no sent grant found for this credential)\($N)"
       else ($g[] | "    \($B)Grant SAID:\($N)      \($Y)\($B)\(.grant)\($N)   \(if .response then "response: " + .response else "no response yet" end)")
       end),
      ""'
