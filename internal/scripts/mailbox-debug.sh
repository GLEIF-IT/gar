#!/bin/bash

##################################################################
##                                                              ##
##  Script for listing MAILBOX notifications                    ##
##                                                              ##
##  Usage:                                                      ##
##    mailbox-debug.sh -w <witness AID> [kli args...]           ##
##    mailbox-debug.sh --all [kli args...]                      ##
##                                                              ##
##  --all polls every witness of the alias in turn. A sender    ##
##  forwards a message to ONE randomly chosen witness, so a     ##
##  single witness never shows the whole mailbox.               ##
##                                                              ##
##  --alias <name> overrides the alias (default: group AID).    ##
##                                                              ##
##  --from <AID> shows only messages sent by that AID (implies  ##
##  --verbose; the sender is the "i" field of each message).    ##
##                                                              ##
##################################################################

set -o pipefail

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

alias="${INT_GAR_AID_ALIAS}"
all=false
sender=""
summary=false
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)        all=true; shift ;;
    --alias|-a)   alias="$2"; shift 2 ;;
    --from)       sender="$2"; shift 2 ;;
    --summary)    summary=true; shift ;;
    *)            args+=("$1"); shift ;;
  esac
done

debug() {
  if [ "${summary}" = true ]; then
    # One line per message (type, route, sender, dt, SAID, embeds) instead of the first 20 bytes.
    # Senders are labelled with contact aliases (refreshed once per run, best effort).
    if [ ! -f "${INT_GAR_DATA_DIR}/aliases.json" ]; then
      kli contacts list --name "${INT_GAR_NAME}" --passcode "${passcode}" 2>/dev/null \
        | tr -d '\r' | jq -s 'map({(.id): .alias}) | add // {}' > "${INT_GAR_DATA_DIR}/aliases.json" || true
    fi
    kli mailbox debug --name "${INT_GAR_NAME}" --alias "${alias}" --passcode "${passcode}" --verbose "$@" \
      | tr -d '\r' \
      | python3 "${INT_GAR_SCRIPT_DIR}/mailbox_summary.py" "${INT_GAR_DATA_DIR}/aliases.json"
    return
  fi
  if [ -z "${sender}" ]; then
    kli mailbox debug --name "${INT_GAR_NAME}" --alias "${alias}" --passcode "${passcode}" "$@"
    return
  fi

  # Verbose output is one blank-line separated block per message. Keep the local
  # index block and the "Messages:" header, then only blocks containing the AID.
  kli mailbox debug --name "${INT_GAR_NAME}" --alias "${alias}" --passcode "${passcode}" --verbose "$@" \
    | tr -d '\r' \
    | awk '{print} /^Messages:$/{print ""}' \
    | awk -v aid="${sender}" '
        BEGIN { RS=""; ORS="\n\n" }
        NR <= 2 { print; next }
        index($0, aid) { print; n++ }
        END { if (!n) print "   (no messages from " aid ")" }'
}

rm -f "${INT_GAR_DATA_DIR}/aliases.json"   # regenerate per run
if [ "${all}" = true ]; then
  # kli status --verbose prints "Witnesses:" followed by "\t1. <AID>" lines, then a blank line.
  # kli runs under docker -t, so strip the \r the pseudo-terminal appends to every line.
  wits=$(kli status --name "${INT_GAR_NAME}" --alias "${alias}" --passcode "${passcode}" --verbose \
         | tr -d '\r' \
         | awk '/^Witnesses:/{f=1; next} f && /^[[:space:]]*[0-9]+\. /{print $2} f && /^[[:space:]]*$/{f=0}')

  if [ -z "${wits}" ]; then
    echo "no witnesses found for alias '${alias}'" >&2
    exit 1
  fi

  for w in ${wits}; do
    echo "=================== Witness ${w} ==================="
    debug --witness "${w}" "${args[@]}" || echo "!! mailbox debug failed for witness ${w}" >&2
    echo
  done
else
  debug "${args[@]}"
fi
