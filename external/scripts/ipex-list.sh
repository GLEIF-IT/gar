#!/bin/bash

##################################################################
##                                                              ##
##  Script for listing IPEX notifications (GRANT, ADMIT, etc.)  ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

# Here's your credentials:
kli ipex list --name "${EXT_GAR_NAME}" --passcode "${passcode}" --poll "$@"