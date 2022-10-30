#!/bin/bash

##################################################################
##                                                              ##
##        Script for creating local External GAR AID            ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

# Here's your AID:
kli status --name "${EXT_GAR_NAME}" --alias "${EXT_GAR_ALIAS}" --passcode "${passcode}"