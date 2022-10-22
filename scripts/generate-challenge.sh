#!/bin/bash

##################################################################
##                                                              ##
##      Script for generating random challenge phrase           ##
##                                                              ##
##################################################################

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

read -p "Enter the Alias to whom you will send the words: " -r alias

kli challenge verify --generate --out string --name "${EXT_GAR_NAME}" --passcode "${passcode}" --alias "${EXT_GAR_ALIAS}" --signer "${alias}"
