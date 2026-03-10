#!/bin/bash

##################################################################
##                                                              ##
##       Script for sending full KEL to a witness to catch up   ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

read -p "Enter the Witness AID: " -r witness

kli witness catchup --name "${INT_GAR_NAME}" --passcode "${passcode}" --alias "${INT_GAR_AID_ALIAS}" --witness "${witness}" "$@"
