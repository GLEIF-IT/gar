#!/bin/bash

##################################################################
##                                                              ##
##             Script for creating multisig aid                 ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

kli multisig interact --name "${EXT_GAR_NAME}" --passcode "${passcode}"  --alias "GLEIF External AID" --data @"/scripts/anchor.json"