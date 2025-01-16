#!/bin/bash

##################################################################
##                                                              ##
##      Script for migrating                                    ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s ext-gar-passcode)"

kli migrate run --name "${EXT_GAR_NAME}" --passcode "${passcode}"