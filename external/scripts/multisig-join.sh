#!/bin/bash

##################################################################
##                                                              ##
##              Script for join a multisig aid                  ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

kli multisig join --name "${EXT_GAR_NAME}" --passcode "${passcode}"
