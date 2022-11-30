#!/bin/bash

##################################################################
##                                                              ##
##      Script for continuing a multisig event process          ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

read -p "Enter the Alias to submit: " -r alias

kli witness submit --name "${INT_GAR_NAME}" --passcode "${passcode}" --alias "${alias}"
