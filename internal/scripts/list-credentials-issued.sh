#!/bin/bash

##################################################################
##                                                              ##
##          Script for listing credentials issued by            ##
##          Internal GAR filtered by issuee AID                 ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

if [ -z "$1" ]; then
    echo "Usage: $0 <issuee_AID>"
    echo "  Lists credentials issued by Internal GAR to the specified issuee AID"
    exit 1
fi

issuee="$1"
shift

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

kli vc list \
    --name "${INT_GAR_NAME}" \
    --passcode "${passcode}" \
    --alias "${INT_GAR_AID_ALIAS}" \
    --issued \
    --poll "$@" \
    | jq -c 'select(.a.AID == "'"${issuee}"'")'
