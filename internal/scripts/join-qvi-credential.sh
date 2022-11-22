#!/bin/bash

##################################################################
##                                                              ##
##           Script for joining credential issuance             ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

read -p "Enter the filename of the new credential: " -r filename

kli vc issue --name "${INT_GAR_NAME}" --passcode "${passcode}" --alias "${INT_GAR_ALIAS}" --credential @"${filename}"
