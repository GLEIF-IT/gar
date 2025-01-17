#!/bin/bash

##################################################################
##                                                              ##
##      Script for migrating                                    ##
##                                                              ##
##################################################################

PWD=$(pwd)
source $PWD/source.sh

passcode="$(security find-generic-password -w -a "${LOGNAME}" -s int-gar-passcode)"

kli migrate run --name "${INT_GAR_NAME}" --passcode "${passcode}"