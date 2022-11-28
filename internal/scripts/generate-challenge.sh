#!/bin/bash

##################################################################
##                                                              ##
##      Script for generating random challenge phrase           ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

read -p "Enter the Alias to whom you will send the words: " -r alias

kli challenge verify --generate --out string --name "${INT_GAR_NAME}" --passcode "${passcode}" --alias "${INT_GAR_ALIAS}" --signer "${alias}"
