#!/bin/bash

##################################################################
##                                                              ##
##  Script for listing IPEX notifications (GRANT, ADMIT, etc.)  ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

# Here's your credentials:
kli ipex list --name "${INT_GAR_NAME}" --passcode "${passcode}" --poll "$@"