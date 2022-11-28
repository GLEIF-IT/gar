#!/bin/bash

##################################################################
##                                                              ##
##             Script for creating multisig aid                 ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

read -p "Enter an Alias for the Group Multisig AID: " -r alias
read -p "Enter the filename of the inception configuration file: " -r filename

kli multisig incept  --name "${INT_GAR_NAME}" --passcode "${passcode}"  --alias "${INT_GAR_ALIAS}" --group "${alias}" --file "${filename}"
