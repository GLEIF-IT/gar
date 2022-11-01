#!/bin/bash

##################################################################
##                                                              ##
##      Script for generating your OOBI to send to others       ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

kli oobi generate --name "${EXT_GAR_NAME}" --passcode "${passcode}" --role witness
