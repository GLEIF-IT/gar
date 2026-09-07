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
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

alias="${INT_GAR_AID_ALIAS}"
all=false
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)        all=true; shift ;;
    --alias|-a)   alias="$2"; shift 2 ;;
    *)            args+=("$1"); shift ;;
  esac
done

debug() {
  kli mailbox debug --name "${INT_GAR_NAME}" --alias "${alias}" --passcode "${passcode}" "$@"
}

if [ "${all}" = true ]; then
  # kli status --verbose prints "Witnesses:" followed by "\t1. <AID>" lines, then a blank line.
  wits=$(kli status --name "${INT_GAR_NAME}" --alias "${alias}" --passcode "${passcode}" --verbose \
         | awk '/^Witnesses:/{f=1; next} f && /^[[:space:]]*[0-9]+\. /{print $2} f && /^[[:space:]]*$/{f=0}')

  if [ -z "${wits}" ]; then
    echo "no witnesses found for alias '${alias}'" >&2
    exit 1
  fi

  for w in ${wits}; do
    echo "=================== Witness ${w} ==================="
    debug --witness "${w}" "${args[@]}"
    echo
  done
else
  debug "${args[@]}"
fi
