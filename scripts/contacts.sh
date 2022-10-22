#!/bin/bash

##################################################################
##                                                              ##
##      Script for listing aliases for remote contacts          ##
##                                                              ##
##################################################################
# Capture password and salt
passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

echo ""
kli contacts list --name "${EXT_GAR_NAME}" --passcode "${passcode}" | jq '"Alias: "+.alias+"\nAID:   "+.id+"\nAuthenticated: "+ if .challenges | length > 0 then "True" else "False" end +"\n"' --raw-output
