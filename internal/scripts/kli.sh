#!/bin/bash

##################################################################
##                                                              ##
##          Script for executing random kli commands            ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

# Capture password
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

# Run the sub command
kli "$@" --name "${INT_GAR_NAME}" --passcode "${passcode}"