#!/bin/bash

##################################################################
##                                                              ##
##              Script for join a multisig aid                  ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

kli multisig join --name "${INT_GAR_NAME}" --passcode "${passcode}"
