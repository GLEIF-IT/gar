#!/bin/bash

##################################################################
##                                                              ##
##             Script for creating multisig aid                 ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

kli rotate --name "${INT_GAR_NAME}" --alias "${INT_GAR_ALIAS}" --passcode "${passcode}"  "$@"
