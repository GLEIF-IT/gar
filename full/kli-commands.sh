#!/bin/bash

##################################################################
##                                                              ##
##          KLI Commands proxied by Docker Containers           ##
##                                                              ##
##################################################################

KEYSTORE_DIR=${1:-"${HOME}"/.fullchain_docker}

if [ ! -d "${KEYSTORE_DIR}" ]; then
    echo "Creating Keystore directory ${KEYSTORE_DIR}"
    mkdir -p "${KEYSTORE_DIR}"
fi

# Set current working directory for all scripts that must access files
KLI1IMAGE="weboftrust/keri:1.1.27"
# KLI2IMAGE="weboftrust/keri:1.2.0-rc1"
KLI2IMAGE="weboftrust/keri:1.1.27"
LOCAL_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export KLI_DATA_DIR="${LOCAL_DIR}/data"
export KLI_CONFIG_DIR="${LOCAL_DIR}/config"

function kli() {
  docker run -it --rm \
    --network host \
    -v "${KEYSTORE_DIR}":/usr/local/var/keri \
    -v "${KLI_CONFIG_DIR}:/config" \
    -v "${KLI_DATA_DIR}":/data \
    -e PYTHONWARNINGS="ignore::SyntaxWarning" \
    "${KLI1IMAGE}" "$@"
}

export -f kli

function klid() {
  echo "$@"
  name=$1
  # must pull first arg off to use as container name
  shift 1
  # pass remaining args to docker run
  docker run -d \
    --network host \
    --name $name \
    -v "${KEYSTORE_DIR}":/usr/local/var/keri \
    -v "${KLI_CONFIG_DIR}:/config" \
    -v "${KLI_DATA_DIR}":/data \
    -e PYTHONWARNINGS="ignore::SyntaxWarning" \
    "${KLI1IMAGE}" "$@" 
}

export -f klid

function kli2() {
  docker run -it --rm \
    --network host \
    -v "${KEYSTORE_DIR}":/usr/local/var/keri \
    -v "${KLI_CONFIG_DIR}:/config" \
    -v "${KLI_DATA_DIR}":/data \
    -e PYTHONWARNINGS="ignore::SyntaxWarning" \
    "${KLI2IMAGE}" "$@"
}

export -f kli2

function kli2d() {
  docker run -d \
    --network host \
    --name $1 \
    -v "${KEYSTORE_DIR}":/usr/local/var/keri \
    -v "${KLI_CONFIG_DIR}:/config" \
    -v "${KLI_DATA_DIR}":/data \
    -e PYTHONWARNINGS="ignore::SyntaxWarning" \
    "${KLI2IMAGE}" "$@:2"
}

export -f kli2d

echo "Keystore directory is ${KEYSTORE_DIR}"
echo "Data directory is ${KLI_DATA_DIR}"
echo "Config directory is ${KLI_CONFIG_DIR}"