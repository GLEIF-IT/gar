#!/bin/bash

##################################################################
##                                                              ##
##       Script for sending full KEL to a witness to catch up   ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

read -p "Enter the Alias: " -r alias
read -p "Enter the Witness AID: " -r witness

kli witness catchup --name "${EXT_GAR_NAME}" --passcode "${passcode}" --alias "${alias}" --witness "${witness}" "$@"
