#!/bin/bash

##################################################################
##                                                              ##
##      Script for resolving OOBIs of other participants        ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

read -p "Type or paste challenge sent to you: " -r words
read -p "Enter the Alias who sent you the words: " -r alias

echo " "
kli challenge respond --name "${INT_GAR_NAME}" --passcode "${passcode}" --alias "${INT_GAR_ALIAS}" --words "${words}" --recipient "${alias}"
echo "Challenge phrase signed and sent"