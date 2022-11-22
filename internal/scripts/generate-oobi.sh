#!/bin/bash

##################################################################
##                                                              ##
##      Script for generating your OOBI to send to others       ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

kli oobi generate --name "${INT_GAR_NAME}" --passcode "${passcode}" --role witness
