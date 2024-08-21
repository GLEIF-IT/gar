#!/bin/bash

##################################################################
##                                                              ##
##             Script for querying the keystate of a contact    ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

echo "Enter contact to refresh keystate from"
read -p "Enter contact identifier prefix: " -r contact_pre

kli query --name "${INT_GAR_NAME}" --alias "${INT_GAR_ALIAS}" --passcode "${passcode}"  --prefix "${contact_pre}"
