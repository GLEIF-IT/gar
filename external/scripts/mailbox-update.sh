#!/bin/bash

##################################################################
##                                                              ##
##  Script for listing MAILBOX notifications                    ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

# Here's your credentials:
# Default alias is the group AID; pass --alias/-a <name> to target another AID,
# e.g. -a "${EXT_GAR_ALIAS}" for your personal AID. The index record is keyed by the
# alias's AID, so updating the wrong alias silently changes a different record.
alias="${EXT_GAR_AID_ALIAS}"
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --alias|-a)   alias="$2"; shift 2 ;;
    *)            args+=("$1"); shift ;;
  esac
done

kli mailbox update --name "${EXT_GAR_NAME}" --alias "${alias}" --passcode "${passcode}" "${args[@]}"