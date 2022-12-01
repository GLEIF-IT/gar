#!/bin/bash

##################################################################
##                                                              ##
##       Script for resend a delegation request event           ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

read -p "Enter the Alias to continue: " -r alias

kli delegate request --name "${EXT_GAR_NAME}" --passcode "${passcode}" --alias "${alias}"
