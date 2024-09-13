#!/usr/bin/env bash
# full-chain.sh
# Runs the entire QVI issuance workflow with multisig AIDs from GLEIF External Delegated AID (GEDA) creation to OOR and ECR credential usage for iXBRL data attestation
#
# To run this script you need to run the following command in a separate terminals:
#   > kli witness demo
# and from the vLEI repo run:
#   > vLEI-server -s ./schema/acdc -c ./samples/acdc/ -o ./samples/oobis/
#

trap ctrl_c INT
function ctrl_c() {
    echo
    print_red "Caught Ctrl+C, Exiting script..."
    exit 0
}

source ./script-utils.sh

# Process outline:
# 1. GAR: Prepare environment

CONFIG_DIR=./
INIT_CFG=full-chain-init-config-dev.json
WAN_PRE=BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha
WIT_HOST=http://127.0.0.1:5642


# GEDA AIDs
GEDA_PT1=accolon
GEDA_PT1_PRE=ENFbr9MI0K7f4Wz34z4hbzHmCTxIPHR9Q_gWjLJiv20h
GEDA_PT1_SALT=0AA2-S2YS4KqvlSzO7faIEpH
GEDA_PT1_PASSCODE=18b2c88fd050851c45c67

GEDA_PT2=bedivere
GEDA_PT2_PRE=EJ7F9XcRW85_S-6F2HIUgXcIcywAy0Nv-GilEBSRnicR
GEDA_PT2_SALT=0ADD292rR7WEU4GPpaYK4Z6h
GEDA_PT2_PASSCODE=b26ef3dd5c85f67c51be8

GEDA_MS=dagonet
GEDA_PRE=EMCRBKH4Kvj03xbEVzKmOIrg0sosqHUF9VG2vzT9ybzv
GEDA_MS_SALT=0ABLokRLKfPg4n49ztPuSPG1
GEDA_MS_PASSCODE=7e6b659da2ff7c4f40fef

GEDA_LEI=254900OPPU84GM83MG36 # GLEIF Americas

# QAR AIDs
QAR_PT1=galahad
QAR_PT1_PRE=ELPwNB8R_CsMNHw_amyp-xnLvpxxTgREjEIvc7oJgqfW
QAR_PT1_SALT=0ACgCmChLaw_qsLycbqBoxDK
QAR_PT1_PASSCODE=e6b3402845de8185abe94

QAR_PT2=lancelot
QAR_PT2_PRE=ENlxz3lZXjEo73a-JBrW1eL8nxSWyLU49-VkuqQZKMtt
QAR_PT2_SALT=0ACaYJJv0ERQmy7xUfKgR6a4
QAR_PT2_PASSCODE=bdf1565a750ff3f76e4fc

QVI_MS=percival
QVI_PRE=EAwP4xBP4C8KzoKCYV2e6767OTnmR5Bt8zmwhUJr9jHh
QVI_MS_SALT=0AA2sMML7K-XdQLrgzOfIvf3
QVI_MS_PASSCODE=97542531221a214cc0a55

# Person AID
PERSON_NAME="Mordred Delacqs"
PERSON=mordred
PERSON_PRE=EIV2RRWifgojIlyX1CyEIJEppNzNKTidpOI7jYnpycne
PERSON_SALT=0ABlXAYDE2TkaNDk4UXxxtaN
PERSON_PASSCODE=c4479ae785625c8e50a7e
PERSON_ECR="Consultant"
PERSON_OOR="Advisor"


# Credentials
GEDA_REGISTRY=vLEI-external
QVI_REGISTRY=vLEI-qvi
QVI_SCHEMA=EBfdlu8R27Fbx-ehrqwImnK-8Cm79sqbAQ4MmvEAYqao
LE_SCHEMA=ENPXp1vQzRF6JwIuS-mp2U8Uf1MoADoP_GqQ62VsDZWY
ECR_AUTH_SCHEMA=EH6ekLjSr8V32WyFbGe1zXjTzFs9PkTYmupJ9H65O14g
OOR_AUTH_SCHEMA=EKA57bKBKxr_kN7iN5i7lMUxpMG-s19dRcmov1iDxz-E
ECR_SCHEMA=EEy9PkikFcANV1l7EHukCeXqrzT1hNZjGlUk7wuMO5jw
OOR_SCHEMA=EBNaNu-M9P5cgrnfl2Fvymy4E_jvxxyjb70PRtiANlJy

# functions
temp_icp_config=""
function create_temp_icp_cfg() {
    read -r -d '' ICP_CONFIG_JSON << EOM
{
  "transferable": true,
  "wits": ["$WAN_PRE"],
  "toad": 1,
  "icount": 1,
  "ncount": 1,
  "isith": "1",
  "nsith": "1"
}
EOM

    echo
    print_lcyan "Using temporary AID config file heredoc:"
    print_lcyan "${ICP_CONFIG_JSON}"

    # create temporary file to store json
    temp_icp_config=$(mktemp)

    # write JSON content to the temp file
    echo "$ICP_CONFIG_JSON" > "$temp_icp_config"
    echo
}

# creates a single sig AID
function create_aid() {
    NAME=$1
    SALT=$2
    PASSCODE=$3
    CONFIG_DIR=$4
    CONFIG_FILE=$5
    ICP_FILE=$6

    echo
    kli init \
        --name "${NAME}" \
        --salt "${SALT}" \
        --passcode "${PASSCODE}" \
        --config-dir "${CONFIG_DIR}" \
        --config-file "${CONFIG_FILE}"
    kli incept \
        --name "${NAME}" \
        --alias "${NAME}" \
        --passcode "${PASSCODE}" \
        --file "${ICP_FILE}"
    # Need this since resolving with bootstrap config file isn't working
    resolve_credential_oobis "${NAME}" "${PASSCODE}"
    echo
    print_green "Created AID: ${NAME}"
    echo
    
}

function resolve_credential_oobis() {
    # Need this function because for some reason resolving more than 8 OOBIs with the bootstrap config file doesn't work
    NAME=$1
    PASSCODE=$2
    echo
    print_green "Resolving credential OOBIs for ${NAME}"
    # LE ECR
    kli oobi resolve \
        --name "${NAME}" \
        --passcode "${PASSCODE}" \
        --oobi "http://127.0.0.1:7723/oobi/EEy9PkikFcANV1l7EHukCeXqrzT1hNZjGlUk7wuMO5jw"
    # LE
    kli oobi resolve \
        --name "${NAME}" \
        --passcode "${PASSCODE}" \
        --oobi "http://127.0.0.1:7723/oobi/ENPXp1vQzRF6JwIuS-mp2U8Uf1MoADoP_GqQ62VsDZWY"
    echo
}

# 2. GAR: Create single Sig AIDs (2)
function create_aids() {
    if test -d $HOME/.keri/ks/${GEDA_PT1}; then
        print_dark_gray "AIDs already exist"
        return
    fi
    echo
    print_green "Creating AIDs"
    create_temp_icp_cfg
    create_aid "${GEDA_PT1}" "${GEDA_PT1_SALT}" "${GEDA_PT1_PASSCODE}" "${CONFIG_DIR}" "${INIT_CFG}" "${temp_icp_config}"
    create_aid "${GEDA_PT2}" "${GEDA_PT2_SALT}" "${GEDA_PT2_PASSCODE}" "${CONFIG_DIR}" "${INIT_CFG}" "${temp_icp_config}"
    create_aid "${QAR_PT1}" "${QAR_PT1_SALT}" "${QAR_PT1_PASSCODE}" "${CONFIG_DIR}" "${INIT_CFG}" "${temp_icp_config}"
    create_aid "${QAR_PT2}" "${QAR_PT2_SALT}" "${QAR_PT2_PASSCODE}" "${CONFIG_DIR}" "${INIT_CFG}" "${temp_icp_config}"
    create_aid "${PERSON}" "${PERSON_SALT}" "${PERSON_PASSCODE}" "${CONFIG_DIR}" "${INIT_CFG}" "${temp_icp_config}"
    rm "$temp_icp_config"
    echo
}
create_aids

# 3. GAR: OOBI and Challenge GAR single sig AIDs
function resolve_oobis() {
    if test -f $HOME/.keri/full-chain-oobis; then
        print_dark_gray "OOBIs already resolved"
        return
    fi

    echo
    print_lcyan "Resolving OOBIs"
    kli oobi resolve --name "${GEDA_PT1}" --oobi-alias "${GEDA_PT2}" --passcode "${GEDA_PT1_PASSCODE}" --oobi "${WIT_HOST}/oobi/${GEDA_PT2_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${GEDA_PT1}" --oobi-alias "${QAR_PT1}"  --passcode "${GEDA_PT1_PASSCODE}" --oobi "${WIT_HOST}/oobi/${QAR_PT1_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${GEDA_PT1}" --oobi-alias "${QAR_PT2}"  --passcode "${GEDA_PT1_PASSCODE}" --oobi "${WIT_HOST}/oobi/${QAR_PT2_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${GEDA_PT1}" --oobi-alias "${PERSON}" --passcode "${GEDA_PT1_PASSCODE}" --oobi "${WIT_HOST}/oobi/${PERSON_PRE}/witness/${WAN_PRE}"

    kli oobi resolve --name "${GEDA_PT2}" --oobi-alias "${GEDA_PT1}" --passcode "${GEDA_PT2_PASSCODE}" --oobi "${WIT_HOST}/oobi/${GEDA_PT1_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${GEDA_PT2}" --oobi-alias "${QAR_PT2}"  --passcode "${GEDA_PT2_PASSCODE}" --oobi "${WIT_HOST}/oobi/${QAR_PT2_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${GEDA_PT2}" --oobi-alias "${QAR_PT1}"  --passcode "${GEDA_PT2_PASSCODE}" --oobi "${WIT_HOST}/oobi/${QAR_PT1_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${GEDA_PT2}" --oobi-alias "${PERSON}" --passcode "${GEDA_PT2_PASSCODE}" --oobi "${WIT_HOST}/oobi/${PERSON_PRE}/witness/${WAN_PRE}"

    kli oobi resolve --name "${QAR_PT1}" --oobi-alias "${QAR_PT2}"  --passcode "${QAR_PT1_PASSCODE}" --oobi "${WIT_HOST}/oobi/${QAR_PT2_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${QAR_PT1}" --oobi-alias "${GEDA_PT1}" --passcode "${QAR_PT1_PASSCODE}" --oobi "${WIT_HOST}/oobi/${GEDA_PT1_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${QAR_PT1}" --oobi-alias "${GEDA_PT2}" --passcode "${QAR_PT1_PASSCODE}" --oobi "${WIT_HOST}/oobi/${GEDA_PT2_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${QAR_PT1}" --oobi-alias "${PERSON}" --passcode "${QAR_PT1_PASSCODE}" --oobi "${WIT_HOST}/oobi/${PERSON_PRE}/witness/${WAN_PRE}"

    kli oobi resolve --name "${QAR_PT2}" --oobi-alias "${QAR_PT1}"  --passcode "${QAR_PT2_PASSCODE}" --oobi "${WIT_HOST}/oobi/${QAR_PT1_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${QAR_PT2}" --oobi-alias "${GEDA_PT2}" --passcode "${QAR_PT2_PASSCODE}" --oobi "${WIT_HOST}/oobi/${GEDA_PT2_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${QAR_PT2}" --oobi-alias "${GEDA_PT1}" --passcode "${QAR_PT2_PASSCODE}" --oobi "${WIT_HOST}/oobi/${GEDA_PT1_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${QAR_PT2}" --oobi-alias "${PERSON}" --passcode "${QAR_PT2_PASSCODE}" --oobi "${WIT_HOST}/oobi/${PERSON_PRE}/witness/${WAN_PRE}"

    kli oobi resolve --name "${PERSON}" --oobi-alias "${QAR_PT1}" --passcode "${PERSON_PASSCODE}" --oobi "${WIT_HOST}/oobi/${QAR_PT1_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${PERSON}" --oobi-alias "${QAR_PT2}" --passcode "${PERSON_PASSCODE}" --oobi "${WIT_HOST}/oobi/${QAR_PT2_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${PERSON}" --oobi-alias "${GEDA_PT1}" --passcode "${PERSON_PASSCODE}" --oobi "${WIT_HOST}/oobi/${GEDA_PT1_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${PERSON}" --oobi-alias "${GEDA_PT2}" --passcode "${PERSON_PASSCODE}" --oobi "${WIT_HOST}/oobi/${GEDA_PT2_PRE}/witness/${WAN_PRE}"
    
    echo

    touch $HOME/.keri/full-chain-oobis
}
resolve_oobis

# 4. GAR: Create Multisig AID (GEDA)
function create_geda_multisig() {
    if test -f $HOME/.keri/full-chain-geda-ms; then
    print_dark_gray "GEDA Multisig AID ${GEDA_MS} already exists"
    return
    fi

    echo
    print_yellow "Multisig Inception for GEDA"

    echo
    print_yellow "Multisig Inception temp config file."
    read -r -d '' MULTISIG_ICP_CONFIG_JSON << EOM
{
  "aids": [
    "${GEDA_PT1_PRE}",
    "${GEDA_PT2_PRE}"
  ],
  "transferable": true,
  "wits": ["${WAN_PRE}"],
  "toad": 1,
  "isith": "2",
  "nsith": "2"
}
EOM

    print_lcyan "Using temporary multisig config file as heredoc:"
    print_lcyan "${MULTISIG_ICP_CONFIG_JSON}"

    # create temporary file to store json
    temp_multisig_config=$(mktemp)

    # write JSON content to the temp file
    echo "$MULTISIG_ICP_CONFIG_JSON" > "$temp_multisig_config"

    # Follow commands run in parallel
    print_yellow "Multisig Inception from ${GEDA_PT1}: ${GEDA_PT1_PRE}"
    kli multisig incept --name ${GEDA_PT1} --alias ${GEDA_PT1} \
        --passcode ${GEDA_PT1_PASSCODE} \
        --group ${GEDA_MS} \
        --file "${temp_multisig_config}" &
    pid=$!
    PID_LIST+=" $pid"

    echo

    kli multisig join --name ${GEDA_PT2} \
        --passcode ${GEDA_PT2_PASSCODE} \
        --group ${GEDA_MS} \
        --auto &
    pid=$!
    PID_LIST+=" $pid"

    echo
    print_yellow "Multisig Inception { ${GEDA_PT1}, ${GEDA_PT2} } - wait for signatures"
    echo
    wait $PID_LIST

    rm "$temp_multisig_config"

    touch $HOME/.keri/full-chain-geda-ms
}
create_geda_multisig
# 5. GAR: Generate OOBI for GEDA to send to AVI
# done in step 9 below in the function

# 6. QAR: Create identifiers (2)
# created in step 2

# 7. QAR: OOBI and Challenge QAR single sig AIDs
# completed in step 3

# 8. QAR: OOBI and Challenge GAR single sig AIDs
# completed in step 3

# 9. QAR: Resolve GEDA OOBI
function resolve_geda_oobi() {
    if test -f $HOME/.keri/full-chain-qar-geda-oobi; then
        print_dark_gray "GEDA OOBI already resolved for QARs"
        return
    fi
    GEDA_OOBI=$(kli oobi generate --name ${GEDA_PT1} --passcode ${GEDA_PT1_PASSCODE} --alias ${GEDA_MS} --role witness)
    echo "GEDA OOBI: ${GEDA_OOBI}"
    kli oobi resolve --name "${QAR_PT1}" --oobi-alias "${GEDA_MS}" --passcode "${QAR_PT1_PASSCODE}" --oobi "${GEDA_OOBI}"
    kli oobi resolve --name "${QAR_PT2}" --oobi-alias "${GEDA_MS}" --passcode "${QAR_PT2_PASSCODE}" --oobi "${GEDA_OOBI}"
    touch $HOME/.keri/full-chain-qar-geda-oobi
}
resolve_geda_oobi

# 10. QAR: Create delegated multisig QVI AID
# 11. QVI: Create delegated AID with GEDA as delegator
# 12. GEDA: delegate to QVI
function create_qvi_multisig() {
    if test -f $HOME/.keri/full-chain-qvi-ms; then
    print_dark_gray "QVI delegated multisig AID ${QVI_MS} already exists"
    return
    fi

    echo
    print_yellow "QVI delegated multisig inception from ${GEDA_MS} | ${GEDA_PRE}"

    echo
    print_yellow "QVI Multisig Inception temp config file."
    read -r -d '' MULTISIG_ICP_CONFIG_JSON << EOM
{
  "delpre": "${GEDA_PRE}",
  "aids": [
    "${QAR_PT1_PRE}",
    "${QAR_PT2_PRE}"
  ],
  "transferable": true,
  "wits": ["${WAN_PRE}"],
  "toad": 1,
  "isith": "2",
  "nsith": "2"
}
EOM

    print_lcyan "QVI delegated multisig config file as heredoc:"
    print_lcyan "${MULTISIG_ICP_CONFIG_JSON}"

    # create temporary file to store json
    temp_multisig_config=$(mktemp)

    # write JSON content to the temp file
    echo "$MULTISIG_ICP_CONFIG_JSON" > "$temp_multisig_config"

    # Follow commands run in parallel
    echo
    print_yellow "QVI delegated multisig inception from ${QAR_PT1}: ${QAR_PT1_PRE}"

    PID_LIST=""
    kli multisig incept --name ${QAR_PT1} --alias ${QAR_PT1} \
        --passcode ${QAR_PT1_PASSCODE} \
        --group ${QVI_MS} \
        --file "${temp_multisig_config}" &
    pid=$!
    PID_LIST+=" $pid"

    echo

    kli multisig incept --name ${QAR_PT2} --alias ${QAR_PT2} \
        --passcode ${QAR_PT2_PASSCODE} \
        --group ${QVI_MS} \
        --file "${temp_multisig_config}" &
    pid=$!
    PID_LIST+=" $pid"

    echo
    print_yellow "QVI delegated multisig Inception { ${QAR_PT1}, ${QAR_PT2} } - wait for signatures"
    sleep 5
    echo

    print_lcyan "Continue after the members of the delegated inception join..."
    echo

    kli delegate confirm --name ${GEDA_PT1} --alias ${GEDA_PT1} --passcode ${GEDA_PT1_PASSCODE} --interact --auto &
    pid=$!
    PID_LIST+=" $pid"
    
    kli delegate confirm --name ${GEDA_PT2} --alias ${GEDA_PT2} --passcode ${GEDA_PT2_PASSCODE} --interact --auto &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    rm "$temp_multisig_config"

    echo
    print_lcyan "Show multisig status for ${QAR_PT1}"
    kli status --name ${QAR_PT1} --alias ${QVI_MS} --passcode ${QAR_PT1_PASSCODE}
    echo

    touch $HOME/.keri/full-chain-qvi-ms
}
create_qvi_multisig

# 13. QVI: (skip) Perform endpoint role authorizations

# 14. QVI: Generate OOBI for QVI to send to GEDA
QVI_OOBI=$(kli oobi generate --name ${QAR_PT1} --passcode ${QAR_PT1_PASSCODE} --alias ${QVI_MS} --role witness)

# 15. GEDA: Resolve QVI OOBI
function resolve_qvi_oobi() {
    if test -f $HOME/.keri/full-chain-geda-qvi-oobi; then
        print_dark_gray "GEDA QVI OOBI already resolved"
        return
    fi

    echo
    echo "QVI OOBI: ${QVI_OOBI}"
    kli oobi resolve --name "${GEDA_PT1}" --oobi-alias "${QVI_MS}" --passcode "${GEDA_PT1_PASSCODE}" --oobi "${QVI_OOBI}"
    kli oobi resolve --name "${GEDA_PT2}" --oobi-alias "${QVI_MS}" --passcode "${GEDA_PT2_PASSCODE}" --oobi "${QVI_OOBI}"
    kli oobi resolve --name "${PERSON}" --oobi-alias "${QVI_MS}" --passcode "${PERSON_PASSCODE}" --oobi "${QVI_OOBI}"
    echo

    touch $HOME/.keri/full-chain-geda-qvi-oobi
}
resolve_qvi_oobi

        
# 15.5 GEDA: Create GEDA credential registry
function create_geda_reg() {
    # Check if GEDA credential registry already exists
    REGISTRY=$(kli vc registry list \
        --name "${GEDA_PT1}" \
        --passcode "${GEDA_PT1_PASSCODE}" | awk '{print $1}')
    if [ ! -z "${REGISTRY}" ]; then
        print_dark_gray "GEDA registry already created"
        return
    fi

    echo
    print_yellow "Creating GEDA registry"
    NONCE=$(kli nonce)
    PID_LIST=""
    kli vc registry incept \
        --name ${GEDA_PT1} \
        --alias ${GEDA_MS} \
        --passcode ${GEDA_PT1_PASSCODE} \
        --usage "QVI Credential Registry for GEDA" \
        --nonce ${NONCE} \
        --registry-name ${GEDA_REGISTRY} &
    pid=$!
    PID_LIST+=" $pid"

    kli vc registry incept \
        --name ${GEDA_PT2} \
        --alias ${GEDA_MS} \
        --passcode ${GEDA_PT2_PASSCODE} \
        --usage "QVI Credential Registry for GEDA" \
        --nonce ${NONCE} \
        --registry-name ${GEDA_REGISTRY} & 
    pid=$!
    PID_LIST+=" $pid"
    wait $PID_LIST

    echo
    print_green "QVI Credential Registry created for GEDA"
    echo
}
create_geda_reg

function prepare_qvi_cred_data() {
    print_bg_blue "Preparing QVI credential data"
    read -r -d '' QVI_CRED_DATA << EOM
{
    "LEI": "${GEDA_LEI}"
}
EOM

    echo "$QVI_CRED_DATA" > ./qvi-cred-data.json

    print_lcyan "QVI Credential Data"
    print_lcyan "$(cat ./qvi-cred-data.json)"
}
prepare_qvi_cred_data

# 16. GEDA: Create QVI credential
function create_qvi_credential() {
    # Check if QVI credential already exists
    SAID=$(kli vc list \
        --name "${GEDA_PT1}" \
        --alias "${GEDA_MS}" \
        --passcode "${GEDA_PT1_PASSCODE}" \
        --issued \
        --said \
        --schema "${QVI_SCHEMA}")
    if [ ! -z "${SAID}" ]; then
        print_dark_gray "GEDA QVI credential already created"
        return
    fi

    echo
    print_green "GEDA creating QVI credential"
    KLI_TIME=$(kli time)
    PID_LIST=""
    kli vc create \
        --name ${GEDA_PT1} \
        --alias ${GEDA_MS} \
        --passcode ${GEDA_PT1_PASSCODE} \
        --registry-name ${GEDA_REGISTRY} \
        --schema "${QVI_SCHEMA}" \
        --recipient ${QVI_PRE} \
        --data @./qvi-cred-data.json \
        --rules @./rules.json \
        --time ${KLI_TIME} &
    pid=$!
    PID_LIST+=" $pid"

    kli vc create \
        --name ${GEDA_PT2} \
        --alias ${GEDA_MS} \
        --passcode ${GEDA_PT2_PASSCODE} \
        --registry-name ${GEDA_REGISTRY} \
        --schema "${QVI_SCHEMA}" \
        --recipient ${QVI_PRE} \
        --data @./qvi-cred-data.json \
        --rules @./rules.json \
        --time ${KLI_TIME} &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    echo
    print_lcyan "QVI Credential created for GEDA"
    echo
}
create_qvi_credential

# 17. GEDA: IPEX Grant QVI credential to QVI
function grant_qvi_credential() {
    QVI_GRANT_SAID=$(kli ipex list \
        --name "${QAR_PT1}" \
        --alias "${QVI_MS}" \
        --passcode "${QAR_PT1_PASSCODE}" \
        --poll \
        --said)
    if [ ! -z "${QVI_GRANT_SAID}" ]; then
        print_dark_gray "GEDA QVI credential already granted"
        return
    fi
    SAID=$(kli vc list \
        --name "${GEDA_PT1}" \
        --passcode "${GEDA_PT1_PASSCODE}" \
        --alias "${GEDA_MS}" \
        --issued \
        --said \
        --schema "${QVI_SCHEMA}")

    echo
    print_yellow "IPEX GRANTing QVI credential with\n\tSAID ${SAID}\n\tto QVI ${QVI_PRE}"
    KLI_TIME=$(kli time)
    kli ipex grant \
        --name ${GEDA_PT1} \
        --passcode ${GEDA_PT1_PASSCODE} \
        --alias ${GEDA_MS} \
        --said ${SAID} \
        --recipient ${QVI_PRE} \
        --time ${KLI_TIME} &
    pid=$!
    PID_LIST+=" $pid"

    kli ipex join \
        --name ${GEDA_PT2} \
        --passcode ${GEDA_PT2_PASSCODE} \
        --auto &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    echo
    print_yellow "Waiting for IPEX messages to be witnessed"
    sleep 5

    echo
    print_green "Polling for QVI Credential in ${QAR_PT1}..."
    kli ipex list \
            --name "${QAR_PT1}" \
            --alias "${QVI_MS}" \
            --passcode "${QAR_PT1_PASSCODE}" \
            --poll \
            --said

    print_green "Polling for QVI Credential in ${QAR_PT2}..."
    kli ipex list \
            --name "${QAR_PT2}" \
            --alias "${QVI_MS}" \
            --passcode "${QAR_PT2_PASSCODE}" \
            --poll \
            --said

    echo
    print_green "QVI Credential issued to QVI"
    echo
}
grant_qvi_credential


# 18. QVI: Admit QVI credential from GEDA
function admit_qvi_credential() {
    VC_SAID=$(kli vc list \
        --name "${QAR_PT2}" \
        --alias "${QVI_MS}" \
        --passcode "${QAR_PT2_PASSCODE}" \
        --said \
        --schema "${QVI_SCHEMA}")
    if [ ! -z "${VC_SAID}" ]; then
        print_dark_gray "QVI Credential already admitted"
        return
    fi
    SAID=$(kli ipex list \
        --name "${QAR_PT1}" \
        --alias "${QVI_MS}" \
        --passcode "${QAR_PT1_PASSCODE}" \
        --poll \
        --said)

    echo
    print_yellow "Admitting QVI Credential ${SAID} from GEDA"

    KLI_TIME=$(kli time)
    kli ipex admit \
        --name ${QAR_PT1} \
        --passcode ${QAR_PT1_PASSCODE} \
        --alias ${QVI_MS} \
        --said ${SAID} \
        --time "${KLI_TIME}" & 
    pid=$!
    PID_LIST+=" $pid"

    print_green "Admitting QVI Credential as ${QVI_MS} from GEDA"
    kli ipex join \
        --name ${QAR_PT2} \
        --passcode ${QAR_PT2_PASSCODE} \
        --auto &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    echo
    print_green "QVI Credential admitted"
    echo
}
admit_qvi_credential

# 18.5 Create QVI credential registry
function create_qvi_reg() {
    # Check if QVI credential registry already exists
    REGISTRY=$(kli vc registry list \
        --name "${QAR_PT1}" \
        --passcode "${QAR_PT1_PASSCODE}" | awk '{print $1}')
    if [ ! -z "${REGISTRY}" ]; then
        print_dark_gray "QVI registry already created"
        return
    fi

    echo
    print_yellow "Creating QVI registry"
    NONCE=$(kli nonce)
    PID_LIST=""
    kli vc registry incept \
        --name ${QAR_PT1} \
        --alias ${QVI_MS} \
        --passcode ${QAR_PT1_PASSCODE} \
        --usage "Credential Registry for QVI" \
        --nonce ${NONCE} \
        --registry-name ${QVI_REGISTRY} &
    pid=$!
    PID_LIST+=" $pid"

    kli vc registry incept \
        --name ${QAR_PT2} \
        --alias ${QVI_MS} \
        --passcode ${QAR_PT2_PASSCODE} \
        --usage "Credential Registry for QVI" \
        --nonce ${NONCE} \
        --registry-name ${QVI_REGISTRY} & 
    pid=$!
    PID_LIST+=" $pid"
    wait $PID_LIST

    echo
    print_green "Credential Registry created for QVI"
    echo
}
create_qvi_reg

# 19. QVI: Prepare, create, and Issue LE credential to GEDA

# 19.1 Prepare LE edge data
function prepare_qvi_edge() {
    QVI_SAID=$(kli vc list \
        --name ${QAR_PT1} \
        --alias ${QVI_MS} \
        --passcode "${QAR_PT1_PASSCODE}" \
        --said \
        --schema ${QVI_SCHEMA})
    print_bg_blue "Preparing QVI edge with QVI Credential SAID: ${QVI_SAID}"
    read -r -d '' QVI_EDGE_JSON << EOM
{
    "d": "", 
    "qvi": {
        "n": "${QVI_SAID}", 
        "s": "${QVI_SCHEMA}"
    }
}
EOM
    echo "$QVI_EDGE_JSON" > ./qvi-edge.json

    kli saidify --file ./qvi-edge.json
    
    print_lcyan "Legal Entity edge Data"
    print_lcyan "$(cat ./qvi-edge.json | jq )"
}
prepare_qvi_edge      

# 19.2 Prepare LE credential data
function prepare_le_cred_data() {
    print_bg_blue "Preparing LE credential data"
    read -r -d '' LE_CRED_DATA << EOM
{
    "LEI": "${GEDA_LEI}"
}
EOM

    echo "$LE_CRED_DATA" > ./legal-entity-data.json

    print_lcyan "Legal Entity Credential Data"
    print_lcyan "$(cat ./legal-entity-data.json)"
}
prepare_le_cred_data

# 19.3 Create LE credential in QVI
function create_le_credential() {
    # Check if LE credential already exists
    SAID=$(kli vc list \
        --name "${QAR_PT1}" \
        --alias "${QVI_MS}" \
        --passcode "${QAR_PT1_PASSCODE}" \
        --issued \
        --said \
        --schema ${LE_SCHEMA})
    if [ ! -z "${SAID}" ]; then
        print_dark_gray "QVI [LE -> GLEIF] credential already created"
        return
    fi

    echo
    print_green "QVI creating [LE -> GLEIF] credential"

    KLI_TIME=$(kli time)
    PID_LIST=""
    kli vc create \
        --name ${QAR_PT1} \
        --alias ${QVI_MS} \
        --passcode ${QAR_PT1_PASSCODE} \
        --registry-name ${QVI_REGISTRY} \
        --schema "${LE_SCHEMA}" \
        --recipient ${GEDA_PRE} \
        --data @./legal-entity-data.json \
        --edges @./qvi-edge.json \
        --rules @./rules.json \
        --time ${KLI_TIME} &

    pid=$!
    PID_LIST+=" $pid"

    kli vc create \
        --name ${QAR_PT2} \
        --alias ${QVI_MS} \
        --passcode ${QAR_PT2_PASSCODE} \
        --registry-name ${QVI_REGISTRY} \
        --schema "${LE_SCHEMA}" \
        --recipient ${GEDA_PRE} \
        --data @./legal-entity-data.json \
        --edges @./qvi-edge.json \
        --rules @./rules.json \
        --time ${KLI_TIME} &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    echo
    print_lcyan "LE->GLEIF Credential created for QVI"
    echo
}
create_le_credential

function grant_le_credential() {
    # This only works because there will be only one grant in the list for the GEDA
    LE_GRANT_SAID=$(kli ipex list \
        --name "${GEDA_PT1}" \
        --alias "${GEDA_MS}" \
        --type "grant" \
        --passcode "${GEDA_PT1_PASSCODE}" \
        --poll \
        --said)
    if [ ! -z "${LE_GRANT_SAID}" ]; then
        print_dark_gray "LE credential already granted"
        return
    fi
    SAID=$(kli vc list \
        --name "${QAR_PT1}" \
        --passcode "${QAR_PT1_PASSCODE}" \
        --alias "${QVI_MS}" \
        --issued \
        --said \
        --schema ${LE_SCHEMA})

    echo
    print_yellow "IPEX GRANTing LE credential with\n\tSAID ${SAID}\n\tto GEDA ${GEDA_PRE}"
    KLI_TIME=$(kli time)
    kli ipex grant \
        --name ${QAR_PT1} \
        --passcode ${QAR_PT1_PASSCODE} \
        --alias ${QVI_MS} \
        --said ${SAID} \
        --recipient ${GEDA_PRE} \
        --time ${KLI_TIME} &
    pid=$!
    PID_LIST+=" $pid"

    kli ipex join \
        --name ${QAR_PT2} \
        --passcode ${QAR_PT2_PASSCODE} \
        --auto &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    echo
    print_yellow "Waiting for IPEX messages to be witnessed"
    sleep 5

    echo
    print_green "Polling for LE Credential in ${GEDA_PT1}..."
    kli ipex list \
        --name "${GEDA_PT1}" \
        --alias "${GEDA_MS}" \
        --passcode "${GEDA_PT1_PASSCODE}" \
        --type "grant" \
        --poll \
        --said

    print_green "Polling for LE Credential in ${GEDA_PT2}..."
    kli ipex list \
        --name "${GEDA_PT2}" \
        --alias "${GEDA_MS}" \
        --passcode "${GEDA_PT2_PASSCODE}" \
        --type "grant" \
        --poll \
        --said

    echo
    print_green "LE Credential granted to GEDA"
    echo
}
grant_le_credential

# 20. GEDA: Admit LE credential from QVI
function admit_le_credential() {
    VC_SAID=$(kli vc list \
        --name "${GEDA_PT2}" \
        --alias "${GEDA_MS}" \
        --passcode "${GEDA_PT2_PASSCODE}" \
        --said \
        --schema ${LE_SCHEMA})
    if [ ! -z "${VC_SAID}" ]; then
        print_dark_gray "LE Credential already admitted"
        return
    fi
    SAID=$(kli ipex list \
        --name "${GEDA_PT1}" \
        --alias "${GEDA_MS}" \
        --passcode "${GEDA_PT1_PASSCODE}" \
        --type "grant" \
        --poll \
        --said)

    echo
    print_yellow "Admitting LE Credential ${SAID} from ${GEDA_PT1}"

    KLI_TIME=$(kli time)
    kli ipex admit \
        --name ${GEDA_PT1} \
        --passcode ${GEDA_PT1_PASSCODE} \
        --alias ${GEDA_MS} \
        --said ${SAID} \
        --time "${KLI_TIME}" & 
    pid=$!
    PID_LIST+=" $pid"

    print_green "Admitting QVI Credential as ${GEDA_MS} from ${GEDA_PT2}"
    kli ipex join \
        --name ${GEDA_PT2} \
        --passcode ${GEDA_PT2_PASSCODE} \
        --auto &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    echo
    print_green "LE Credential admitted"
    echo
}
admit_le_credential

# 21. GEDA: Prepare, create, and Issue ECR Auth & OOR Auth credential to QVI

# 21.1 prepare LE edge to ECR auth cred
function prepare_le_edge() {
    LE_SAID=$(kli vc list \
        --name ${GEDA_PT1} \
        --alias ${GEDA_MS} \
        --passcode "${GEDA_PT1_PASSCODE}" \
        --said \
        --schema ${LE_SCHEMA})
    print_bg_blue "Preparing ECR Auth cred with LE Credential SAID: ${LE_SAID}"
    read -r -d '' LE_EDGE_JSON << EOM
{
    "d": "", 
    "le": {
        "n": "${LE_SAID}", 
        "s": "${LE_SCHEMA}"
    }
}
EOM

    echo "$LE_EDGE_JSON" > ./legal-entity-edge.json
    kli saidify --file ./legal-entity-edge.json
    
    print_lcyan "Legal Entity edge JSON"
    print_lcyan "$(cat ./legal-entity-edge.json | jq)"
}
prepare_le_edge

# 21.2 Prepare ECR Auth credential data
function prepare_ecr_auth_data() {
    read -r -d '' ECR_AUTH_DATA_JSON << EOM
{
  "AID": "${PERSON_PRE}",
  "LEI": "${GEDA_LEI}",
  "personLegalName": "${PERSON_NAME}",
  "engagementContextRole": "${PERSON_ECR}"
}
EOM

    echo "$ECR_AUTH_DATA_JSON" > ./ecr-auth-data.json
    print_lcyan "ECR Auth data JSON"
    print_lcyan "$(cat ./ecr-auth-data.json)"
}
prepare_ecr_auth_data

# 21.3 Create ECR Auth credential
function create_ecr_auth_credential() {
    # Check if ECR auth credential already exists
    SAID=$(kli vc list \
        --name "${GEDA_PT1}" \
        --alias "${GEDA_MS}" \
        --passcode "${GEDA_PT1_PASSCODE}" \
        --issued \
        --said \
        --schema "${ECR_AUTH_SCHEMA}")
    if [ ! -z "${SAID}" ]; then
        print_dark_gray "GEDA ECR AUTH -> QVI credential already created"
        return
    fi

    echo
    print_green "GEDA creating ECR AUTH -> QVI credential"

    KLI_TIME=$(kli time)
    PID_LIST=""
    kli vc create \
        --name ${GEDA_PT1} \
        --alias ${GEDA_MS} \
        --passcode ${GEDA_PT1_PASSCODE} \
        --registry-name ${GEDA_REGISTRY} \
        --schema ${ECR_AUTH_SCHEMA} \
        --recipient ${QVI_PRE} \
        --data @./ecr-auth-data.json \
        --edges @./legal-entity-edge.json \
        --rules @./ecr-auth-rules.json \
        --time ${KLI_TIME} &

    pid=$!
    PID_LIST+=" $pid"

    kli vc create \
        --name ${GEDA_PT2} \
        --alias ${GEDA_MS} \
        --passcode ${GEDA_PT2_PASSCODE} \
        --registry-name ${GEDA_REGISTRY} \
        --schema ${ECR_AUTH_SCHEMA} \
        --recipient ${QVI_PRE} \
        --data @./ecr-auth-data.json \
        --edges @./legal-entity-edge.json \
        --rules @./ecr-auth-rules.json \
        --time ${KLI_TIME} &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    echo
    print_lcyan "ECR Auth -> QVI Credential created for GEDA"
    echo
}
create_ecr_auth_credential

# 21.4 Grant ECR Auth credential to QVI
function grant_ecr_auth_credential() {
    # This relies on there being only one grant in the list for the GEDA
    GRANT_COUNT=$(kli ipex list \
        --name "${QAR_PT1}" \
        --alias "${QVI_MS}" \
        --type "grant" \
        --passcode "${QAR_PT1_PASSCODE}" \
        --poll \
        --said | wc -l | tr -d ' ') # get the last grant
    if [ "${GRANT_COUNT}" -ge 2 ]; then
        print_dark_gray "ECR_AUTH credential already granted"
        return
    fi
    SAID=$(kli vc list \
        --name "${GEDA_PT1}" \
        --passcode "${GEDA_PT1_PASSCODE}" \
        --alias "${GEDA_MS}" \
        --issued \
        --said \
        --schema ${ECR_AUTH_SCHEMA})

    echo
    print_yellow "IPEX GRANTing ECR Auth credential with\n\tSAID ${SAID}\n\tto QVI ${QVI_PRE}"

    KLI_TIME=$(kli time) # Use consistent time so SAID of grant is same
    kli ipex grant \
        --name ${GEDA_PT1} \
        --passcode ${GEDA_PT1_PASSCODE} \
        --alias ${GEDA_MS} \
        --said ${SAID} \
        --recipient ${QVI_PRE} \
        --time ${KLI_TIME} &
    pid=$!
    PID_LIST+=" $pid"

    kli ipex join \
        --name ${GEDA_PT2} \
        --passcode ${GEDA_PT2_PASSCODE} \
        --auto &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    echo
    print_yellow "Waiting for IPEX messages to be witnessed"
    sleep 5

    echo
    print_green "Polling for ECR Auth Credential in ${QAR_PT1}..."
    kli ipex list \
            --name "${QAR_PT1}" \
            --alias "${QVI_MS}" \
            --passcode "${QAR_PT1_PASSCODE}" \
            --type "grant" \
            --poll \
            --said

    print_green "Polling for ECR Auth Credential in ${QAR_PT2}..."
    kli ipex list \
            --name "${QAR_PT2}" \
            --alias "${QVI_MS}" \
            --passcode "${QAR_PT2_PASSCODE}" \
            --type "grant" \
            --poll \
            --said

    echo
    print_green "ECR AUTH Credential granted to QVI"
    echo
}
grant_ecr_auth_credential

# 21.5 (part of 22) Admit ECR Auth credential from GEDA
function admit_ecr_auth_credential() {
    VC_SAID=$(kli vc list \
        --name "${QAR_PT2}" \
        --alias "${QVI_MS}" \
        --passcode "${QAR_PT2_PASSCODE}" \
        --said \
        --schema ${ECR_AUTH_SCHEMA})
    if [ ! -z "${VC_SAID}" ]; then
        print_dark_gray "ECR Auth Credential already admitted"
        return
    fi
    SAID=$(kli ipex list \
        --name "${QAR_PT1}" \
        --alias "${QVI_MS}" \
        --passcode "${QAR_PT1_PASSCODE}" \
        --type "grant" \
        --poll \
        --said | \
        tail -1) # get the last grant, which should be the ECR Auth credential

    echo
    print_yellow "Admitting ECR Auth Credential ${SAID} from GEDA LE"

    KLI_TIME=$(kli time) # Use consistent time so SAID of grant is same
    kli ipex admit \
        --name ${QAR_PT1} \
        --passcode ${QAR_PT1_PASSCODE} \
        --alias ${QVI_MS} \
        --said ${SAID} \
        --time "${KLI_TIME}" & 
    pid=$!
    PID_LIST+=" $pid"

    print_green "Admitting ECR Auth Credential as ${QVI_MS} from GEDA LE"
    kli ipex join \
        --name ${QAR_PT2} \
        --passcode ${QAR_PT2_PASSCODE} \
        --auto &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    echo
    print_green "ECR Auth Credential admitted"
    echo
}
admit_ecr_auth_credential

# 21.6 Prepare OOR Auth credential data
function prepare_oor_auth_data() {
    read -r -d '' OOR_AUTH_DATA_JSON << EOM
{
  "AID": "${PERSON_PRE}",
  "LEI": "${GEDA_LEI}",
  "personLegalName": "${PERSON_NAME}",
  "officialRole": "${PERSON_OOR}"
}
EOM

    echo "$OOR_AUTH_DATA_JSON" > ./oor-auth-data.json
    print_lcyan "OOR Auth data JSON"
    print_lcyan "$(cat ./oor-auth-data.json)"
}
prepare_oor_auth_data

# 21.7 Create OOR Auth credential
function create_oor_auth_credential() {
    # Check if OOR auth credential already exists
    SAID=$(kli vc list \
        --name "${GEDA_PT1}" \
        --alias "${GEDA_MS}" \
        --passcode "${GEDA_PT1_PASSCODE}" \
        --issued \
        --said \
        --schema "${OOR_AUTH_SCHEMA}")
    if [ ! -z "${SAID}" ]; then
        print_yellow "GEDA [OOR AUTH -> QVI] credential already created"
        return
    fi

    echo
    print_green "GEDA creating [OOR AUTH -> QVI] credential"

    KLI_TIME=$(kli time)
    PID_LIST=""
    kli vc create \
        --name ${GEDA_PT1} \
        --alias ${GEDA_MS} \
        --passcode ${GEDA_PT1_PASSCODE} \
        --registry-name ${GEDA_REGISTRY} \
        --schema ${OOR_AUTH_SCHEMA} \
        --recipient ${QVI_PRE} \
        --data @./oor-auth-data.json \
        --edges @./legal-entity-edge.json \
        --rules @./rules.json \
        --time ${KLI_TIME} &

    pid=$!
    PID_LIST+=" $pid"

    kli vc create \
        --name ${GEDA_PT2} \
        --alias ${GEDA_MS} \
        --passcode ${GEDA_PT2_PASSCODE} \
        --registry-name ${GEDA_REGISTRY} \
        --schema ${OOR_AUTH_SCHEMA} \
        --recipient ${QVI_PRE} \
        --data @./oor-auth-data.json \
        --edges @./legal-entity-edge.json \
        --rules @./rules.json \
        --time ${KLI_TIME} &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    echo
    print_lcyan "GEDA created [OOR Auth -> QVI Credential]"
    echo
}
create_oor_auth_credential

# 21.8 Grant OOR Auth credential to QVI
function grant_oor_auth_credential() {
    # This relies on the last grant being the OOR Auth credential
    GRANT_COUNT=$(kli ipex list \
        --name "${QAR_PT1}" \
        --alias "${QVI_MS}" \
        --type "grant" \
        --passcode "${QAR_PT1_PASSCODE}" \
        --poll \
        --said | wc -l | tr -d ' ') # get grant count, remove whitespace
    if [ "${GRANT_COUNT}" -ge 3 ]; then
        print_dark_gray "ECR_AUTH credential already granted"
        return
    fi
    SAID=$(kli vc list \
        --name "${GEDA_PT1}" \
        --passcode "${GEDA_PT1_PASSCODE}" \
        --alias "${GEDA_MS}" \
        --issued \
        --said \
        --schema ${OOR_AUTH_SCHEMA} | \
        tail -1) # get the last credential, the OOR Auth credential

    echo
    print_yellow "IPEX GRANTing OOR Auth credential with\n\tSAID ${SAID}\n\tto QVI ${QVI_PRE}"

    KLI_TIME=$(kli time) # Use consistent time so SAID of grant is same
    kli ipex grant \
        --name ${GEDA_PT1} \
        --passcode ${GEDA_PT1_PASSCODE} \
        --alias ${GEDA_MS} \
        --said ${SAID} \
        --recipient ${QVI_PRE} \
        --time ${KLI_TIME} &
    pid=$!
    PID_LIST+=" $pid"

    kli ipex join \
        --name ${GEDA_PT2} \
        --passcode ${GEDA_PT2_PASSCODE} \
        --auto &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    echo
    print_yellow "Waiting for IPEX messages to be witnessed"
    sleep 5

    echo
    print_green "Polling for OOR Auth Credential in ${QAR_PT1}..."
    kli ipex list \
            --name "${QAR_PT1}" \
            --alias "${QVI_MS}" \
            --passcode "${QAR_PT1_PASSCODE}" \
            --type "grant" \
            --poll \
            --said

    print_green "Polling for OOR Auth Credential in ${QAR_PT2}..."
    kli ipex list \
            --name "${QAR_PT2}" \
            --alias "${QVI_MS}" \
            --passcode "${QAR_PT2_PASSCODE}" \
            --type "grant" \
            --poll \
            --said

    echo
    print_green "OOR AUTH Credential granted to QVI"
    echo
}
grant_oor_auth_credential

# 22. QVI: Admit OOR Auth & ECR Auth credentials
function admit_oor_auth_credential() {
    VC_SAID=$(kli vc list \
        --name "${QAR_PT2}" \
        --alias "${QVI_MS}" \
        --passcode "${QAR_PT2_PASSCODE}" \
        --said \
        --schema ${OOR_AUTH_SCHEMA})
    if [ ! -z "${VC_SAID}" ]; then
        print_dark_gray "OOR Auth Credential already admitted"
        return
    fi
    SAID=$(kli ipex list \
        --name "${QAR_PT1}" \
        --alias "${QVI_MS}" \
        --passcode "${QAR_PT1_PASSCODE}" \
        --type "grant" \
        --poll \
        --said | \
        tail -1) # get the last grant, which should be the ECR Auth credential

    echo
    print_yellow "Admitting OOR Auth Credential ${SAID} from GEDA LE"

    KLI_TIME=$(kli time) # Use consistent time so SAID of grant is same
    kli ipex admit \
        --name ${QAR_PT1} \
        --passcode ${QAR_PT1_PASSCODE} \
        --alias ${QVI_MS} \
        --said ${SAID} \
        --time "${KLI_TIME}" & 
    pid=$!
    PID_LIST+=" $pid"

    print_green "Admitting OOR Auth Credential as ${QVI_MS} from GEDA LE"
    kli ipex join \
        --name ${QAR_PT2} \
        --passcode ${QAR_PT2_PASSCODE} \
        --auto &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    echo
    print_green "OOR Auth Credential admitted"
    echo
}
admit_oor_auth_credential

# 23. QVI: Create and Issue ECR & OOR credentials to GEDA participants
# 23.1 Prepare ECR Auth edge data
function prepare_ecr_auth_edge() {
    ECR_AUTH_SAID=$(kli vc list \
        --name ${QAR_PT1} \
        --alias ${QVI_MS} \
        --passcode "${QAR_PT1_PASSCODE}" \
        --said \
        --schema ${ECR_AUTH_SCHEMA})
    print_bg_blue "Preparing [ECR Auth] edge with [ECR Auth] Credential SAID: ${ECR_AUTH_SAID}"
    read -r -d '' ECR_AUTH_EDGE_JSON << EOM
{
    "d": "", 
    "auth": {
        "n": "${ECR_AUTH_SAID}", 
        "s": "${ECR_AUTH_SCHEMA}",
        "o": "I2I"
    }
}
EOM
    echo "$ECR_AUTH_EDGE_JSON" > ./ecr-auth-edge.json

    kli saidify --file ./ecr-auth-edge.json
    
    print_lcyan "ECR Auth edge Data"
    print_lcyan "$(cat ./ecr-auth-edge.json | jq )"
}
prepare_ecr_auth_edge      

# 23.2 Prepare ECR credential data
function prepare_ecr_cred_data() {
    print_bg_blue "Preparing ECR credential data"
    read -r -d '' ECR_CRED_DATA << EOM
{
  "LEI": "${GEDA_LEI}",
  "personLegalName": "${PERSON_NAME}",
  "engagementContextRole": "${PERSON_ECR}"
}
EOM

    echo "${ECR_CRED_DATA}" > ./ecr-data.json

    print_lcyan "ECR Credential Data"
    print_lcyan "$(cat ./ecr-data.json)"
}
prepare_ecr_cred_data

# 23.3 Create ECR credential in QVI
function create_ecr_credential() {
    # Check if ECR credential already exists
    SAID=$(kli vc list \
        --name "${QAR_PT1}" \
        --alias "${QVI_MS}" \
        --passcode "${QAR_PT1_PASSCODE}" \
        --issued \
        --said \
        --schema ${ECR_SCHEMA})
    if [ ! -z "${SAID}" ]; then
        print_dark_gray "QVI [ECR -> PERSON] credential already created"
        return
    fi

    echo
    print_green "QVI creating [ECR -> PERSON] credential"

    KLI_TIME=$(kli time)
    PID_LIST=""
    kli vc create \
        --name ${QAR_PT1} \
        --alias ${QVI_MS} \
        --passcode ${QAR_PT1_PASSCODE} \
        --private \
        --registry-name ${QVI_REGISTRY} \
        --schema ${ECR_SCHEMA} \
        --recipient ${GEDA_PRE} \
        --data @./ecr-data.json \
        --edges @./ecr-auth-edge.json \
        --rules @./ecr-rules.json \
        --time ${KLI_TIME} &
    pid=$!
    PID_LIST+=" $pid"

    kli vc create \
        --name ${QAR_PT2} \
        --alias ${QVI_MS} \
        --passcode ${QAR_PT2_PASSCODE} \
        --private \
        --registry-name ${QVI_REGISTRY} \
        --schema ${ECR_SCHEMA} \
        --recipient ${GEDA_PRE} \
        --data @./ecr-data.json \
        --edges @./ecr-auth-edge.json \
        --rules @./ecr-rules.json \
        --time ${KLI_TIME} &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    echo
    print_lcyan "QVI created [ECR -> PERSON] Credential"
    echo
}
create_ecr_credential

# 23.4 Grant ECR credential to PERSON
function grant_ecr_credential() {
    # This only works the last grant is the ECR credential
    ECR_GRANT_SAID=$(kli ipex list \
        --name "${PERSON}" \
        --alias "${PERSON}" \
        --type "grant" \
        --passcode "${PERSON_PASSCODE}" \
        --poll \
        --said | \
        tail -1) # get the last grant
    if [ ! -z "${ECR_GRANT_SAID}" ]; then
        print_yellow "ECR credential already granted"
        return
    fi
    SAID=$(kli vc list \
        --name "${QAR_PT1}" \
        --passcode "${QAR_PT1_PASSCODE}" \
        --alias "${QVI_MS}" \
        --issued \
        --said \
        --schema ${ECR_SCHEMA})

    echo
    print_yellow "IPEX GRANTing ECR credential with\n\tSAID ${SAID}\n\tto ${PERSON} ${PERSON_PRE}"
    KLI_TIME=$(kli time)
    kli ipex grant \
        --name ${QAR_PT1} \
        --passcode ${QAR_PT1_PASSCODE} \
        --alias ${QVI_MS} \
        --said ${SAID} \
        --recipient ${PERSON_PRE} \
        --time ${KLI_TIME} &
    pid=$!
    PID_LIST+=" $pid"

    kli ipex join \
        --name ${QAR_PT2} \
        --passcode ${QAR_PT2_PASSCODE} \
        --auto &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    echo
    print_yellow "Waiting for IPEX messages to be witnessed"
    sleep 5

    echo
    print_green "Polling for ECR Credential in ${PERSON}..."
    kli ipex list \
        --name "${PERSON}" \
        --alias "${PERSON}" \
        --passcode "${PERSON_PASSCODE}" \
        --type "grant" \
        --poll \
        --said

    echo
    print_green "ECR Credential granted to ${PERSON}"
    echo
}
# grant_ecr_credential

# 23.5. GEDA: Admit ECR credential from QVI
function admit_ecr_credential() {
    VC_SAID=$(kli vc list \
        --name "${PERSON}" \
        --alias "${PERSON}" \
        --passcode "${PERSON_PASSCODE}" \
        --said \
        --schema ${ECR_SCHEMA})
    if [ ! -z "${VC_SAID}" ]; then
        print_yellow "ECR Credential already admitted"
        return
    fi
    SAID=$(kli ipex list \
        --name "${PERSON}" \
        --alias "${PERSON}" \
        --passcode "${PERSON_PASSCODE}" \
        --type "grant" \
        --poll \
        --said)

    echo
    print_yellow "Admitting ECR Credential ${SAID} to ${PERSON}"

    kli ipex admit \
        --name ${PERSON} \
        --passcode ${PERSON_PASSCODE} \
        --alias ${PERSON} \
        --said ${SAID}  & 
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    echo
    print_green "ECR Credential admitted"
    echo
}
# admit_ecr_credential
# 24. GEDA: Admit OOR & ECR credentials from QVI

# 25. QVI: Revoke LE, OOR, ECR credentials from GEDA


print_lcyan "Full chain workflow completed"