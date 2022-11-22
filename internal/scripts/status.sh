#!/bin/bash

##################################################################
##                                                              ##
##          Script for showing status of local AIDs             ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

# Here's your AID:
kli status --name "${INT_GAR_NAME}" --passcode "${passcode}"