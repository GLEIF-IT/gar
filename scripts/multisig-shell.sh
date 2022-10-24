#!/bin/bash

##################################################################
##                                                              ##
##           Script for running the multisig shell              ##
##                                                              ##
##################################################################

# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

kli multisig shell --name "${EXT_GAR_NAME}" --passcode "${passcode}"
