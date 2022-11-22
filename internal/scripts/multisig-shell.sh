#!/bin/bash

##################################################################
##                                                              ##
##           Script for running the multisig shell              ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

kli multisig shell --name "${INT_GAR_NAME}" --passcode "${passcode}"
