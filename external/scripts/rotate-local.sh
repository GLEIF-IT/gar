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

kli rotate --name "${EXT_GAR_NAME}" --alias "${EXT_GAR_ALIAS}" --passcode "${passcode}"  "$@"
