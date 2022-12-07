#!/bin/bash

##################################################################
##                                                              ##
##          Script for executing random kli commands            ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

# Run the sub command
kli "$@" --name "${EXT_GAR_NAME}" --passcode "${passcode}"