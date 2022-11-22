#!/bin/bash

##################################################################
##                                                              ##
##           Script for joining credential issuance             ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

read -p "Enter the filename of the new credential: " -r filename

kli vc issue --name "${EXT_GAR_NAME}" --passcode "${passcode}" --alias "${EXT_GAR_ALIAS}" --credential @"${filename}"
