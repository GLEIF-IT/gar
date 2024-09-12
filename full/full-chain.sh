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

# Credentials
GEDA_REGISTRY=vLEI-external
QVI_CRED_SCHEMA=EBfdlu8R27Fbx-ehrqwImnK-8Cm79sqbAQ4MmvEAYqao

# functions
temp_icp_config=""
function create_temp_icp_cfg() {
    # store multisig-stooge.json as a variable
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

  print_lcyan "Using temporary AID config file heredoc:"
  print_lcyan "${ICP_CONFIG_JSON}"

  # create temporary file to store json
  temp_icp_config=$(mktemp)

  # write JSON content to the temp file
  echo "$ICP_CONFIG_JSON" > "$temp_icp_config"
}

# creates a single sig AID
function create_aid() {
    NAME=$1
    SALT=$2
    PASSCODE=$3
    CONFIG_DIR=$4
    CONFIG_FILE=$5
    ICP_FILE=$6

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
}

# 2. GAR: Create single Sig AIDs (2)
function create_aids() {
    if test -d $HOME/.keri/ks/${GEDA_PT1}; then
        print_yellow "AIDs already exist"
        return
    fi
    print_green "Creating AIDs"
    create_temp_icp_cfg
    create_aid "${GEDA_PT1}" "${GEDA_PT1_SALT}" "${GEDA_PT1_PASSCODE}" "${CONFIG_DIR}" "${INIT_CFG}" "${temp_icp_config}"
    create_aid "${GEDA_PT2}" "${GEDA_PT2_SALT}" "${GEDA_PT2_PASSCODE}" "${CONFIG_DIR}" "${INIT_CFG}" "${temp_icp_config}"
    create_aid "${QAR_PT1}" "${QAR_PT1_SALT}" "${QAR_PT1_PASSCODE}" "${CONFIG_DIR}" "${INIT_CFG}" "${temp_icp_config}"
    create_aid "${QAR_PT2}" "${QAR_PT2_SALT}" "${QAR_PT2_PASSCODE}" "${CONFIG_DIR}" "${INIT_CFG}" "${temp_icp_config}"
    rm "$temp_icp_config"
    echo
}
create_aids

# 3. GAR: OOBI and Challenge GAR single sig AIDs
function resolve_oobis() {
    if test -f $HOME/.keri/full-chain-oobis; then
        print_yellow "OOBIs already resolved"
        return
    fi

    print_lcyan "Resolving OOBIs"
    kli oobi resolve --name "${GEDA_PT1}" --oobi-alias "${GEDA_PT2}" --passcode "${GEDA_PT1_PASSCODE}" --oobi "${WIT_HOST}/oobi/${GEDA_PT2_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${GEDA_PT1}" --oobi-alias "${QAR_PT1}" --passcode "${GEDA_PT1_PASSCODE}" --oobi "${WIT_HOST}/oobi/${QAR_PT1_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${GEDA_PT1}" --oobi-alias "${QAR_PT2}" --passcode "${GEDA_PT1_PASSCODE}" --oobi "${WIT_HOST}/oobi/${QAR_PT2_PRE}/witness/${WAN_PRE}"

    kli oobi resolve --name "${GEDA_PT2}" --oobi-alias "${GEDA_PT1}" --passcode "${GEDA_PT2_PASSCODE}" --oobi "${WIT_HOST}/oobi/${GEDA_PT1_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${GEDA_PT2}" --oobi-alias "${QAR_PT2}" --passcode "${GEDA_PT2_PASSCODE}" --oobi "${WIT_HOST}/oobi/${QAR_PT2_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${GEDA_PT2}" --oobi-alias "${QAR_PT1}" --passcode "${GEDA_PT2_PASSCODE}" --oobi "${WIT_HOST}/oobi/${QAR_PT1_PRE}/witness/${WAN_PRE}"

    kli oobi resolve --name "${QAR_PT1}" --oobi-alias "${QAR_PT2}" --passcode "${QAR_PT1_PASSCODE}" --oobi "${WIT_HOST}/oobi/${QAR_PT2_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${QAR_PT1}" --oobi-alias "${GEDA_PT1}" --passcode "${QAR_PT1_PASSCODE}" --oobi "${WIT_HOST}/oobi/${GEDA_PT1_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${QAR_PT1}" --oobi-alias "${GEDA_PT2}" --passcode "${QAR_PT1_PASSCODE}" --oobi "${WIT_HOST}/oobi/${GEDA_PT2_PRE}/witness/${WAN_PRE}"

    kli oobi resolve --name "${QAR_PT2}" --oobi-alias "${QAR_PT1}" --passcode "${QAR_PT2_PASSCODE}" --oobi "${WIT_HOST}/oobi/${QAR_PT1_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${QAR_PT2}" --oobi-alias "${GEDA_PT2}" --passcode "${QAR_PT2_PASSCODE}" --oobi "${WIT_HOST}/oobi/${GEDA_PT2_PRE}/witness/${WAN_PRE}"
    kli oobi resolve --name "${QAR_PT2}" --oobi-alias "${GEDA_PT1}" --passcode "${QAR_PT2_PASSCODE}" --oobi "${WIT_HOST}/oobi/${GEDA_PT1_PRE}/witness/${WAN_PRE}"
    echo
    touch $HOME/.keri/full-chain-oobis
}
resolve_oobis

# 4. GAR: Create Multisig AID (GEDA)
function create_geda_multisig() {
    if test -f $HOME/.keri/full-chain-geda-ms; then
    print_yellow "GEDA Multisig AID ${GEDA_MS} already exists"
    return
    fi

    echo
    print_yellow "Multisig Inception for GEDA"

    # store multisig-two-stooges.json as a variable
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
        print_yellow "QAR GEDA OOBI already resolved"
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
    print_yellow "QVI delegated multisig AID ${QVI_MS} already exists"
    return
    fi

    echo
    print_yellow "QVI delegated multisig inception from ${GEDA_MS} | ${GEDA_PRE}"

    # store multisig-two-stooges.json as a variable
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
    print_yellow "QVI delegated multisig inception from ${QAR_PT1}: ${QAR_PT1_PRE}"
    # read -r -p "Press [ENTER] to start QVI multisig inception with ${QAR_PT1}"
    PID_LIST=""
    kli multisig incept --name ${QAR_PT1} --alias ${QAR_PT1} \
        --passcode ${QAR_PT1_PASSCODE} \
        --group ${QVI_MS} \
        --file "${temp_multisig_config}" &
    pid=$!
    PID_LIST+=" $pid"

    echo

    # read -r -p "Press [ENTER] to join QVI multisig inception with ${QAR_PT2}"
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
    # read -r -p "Press [ENTER] to have ${GEDA_PT1} confirm the delegation"

    kli delegate confirm --name ${GEDA_PT1} --alias ${GEDA_PT1} --passcode ${GEDA_PT1_PASSCODE} --interact --auto &
    pid=$!
    PID_LIST+=" $pid"
    # read -r -p "Press [ENTER] to have ${GEDA_PT2} confirm the delegation"
    kli delegate confirm --name ${GEDA_PT2} --alias ${GEDA_PT2} --passcode ${GEDA_PT2_PASSCODE} --interact --auto &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    rm "$temp_multisig_config"

    kli status --name ${QAR_PT1} --alias ${QVI_MS} --passcode ${QAR_PT1_PASSCODE}

    touch $HOME/.keri/full-chain-qvi-ms
}
create_qvi_multisig

# 13. QVI: (skip) Perform endpoint role authorizations

# 14. QVI: Generate OOBI for QVI to send to GEDA
QVI_OOBI=$(kli oobi generate --name ${QAR_PT1} --passcode ${QAR_PT1_PASSCODE} --alias ${QVI_MS} --role witness)

# 15. GEDA: Resolve QVI OOBI
function resolve_qvi_oobi() {
    if test -f $HOME/.keri/full-chain-geda-qvi-oobi; then
        print_yellow "GEDA QVI OOBI already resolved"
        return
    fi
    echo "QVI OOBI: ${QVI_OOBI}"
    kli oobi resolve --name "${GEDA_PT1}" --oobi-alias "${QVI_MS}" --passcode "${GEDA_PT1_PASSCODE}" --oobi "${QVI_OOBI}"
    kli oobi resolve --name "${GEDA_PT2}" --oobi-alias "${QVI_MS}" --passcode "${GEDA_PT2_PASSCODE}" --oobi "${QVI_OOBI}"
    touch $HOME/.keri/full-chain-geda-qvi-oobi
}
resolve_qvi_oobi

        
# 16. GEDA: Create QVI credential
function create_qvi_reg() {
    # Check if QVI credential registry already exists
    REGISTRY=$(kli vc registry list \
        --name "${GEDA_PT1}" \
        --passcode "${GEDA_PT1_PASSCODE}" | awk '{print $1}')
    if [ ! -z "${REGISTRY}" ]; then
        print_yellow "GEDA QVI registry already created"
        return
    fi

    NONCE=$(kli nonce)
    print_yellow "Creating QVI credential"
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

    print_green "QVI Credential Registry created for GEDA"
}
create_qvi_reg

KLI_TIME=$(kli time)
function create_qvi_credential() {
    # Check if QVI credential already exists
    SAID=$(kli vc list \
        --name "${GEDA_PT1}" \
        --passcode "${GEDA_PT1_PASSCODE}" \
        --alias "${GEDA_MS}" \
        --issued \
        --said \
        --schema ${QVI_CRED_SCHEMA})
    if [ ! -z "${SAID}" ]; then
        print_yellow "GEDA QVI credential already created"
        return
    fi

    # KLI_TIME=$(kli time)
    PID_LIST=""
    kli vc create \
        --name ${GEDA_PT1} \
        --alias ${GEDA_MS} \
        --passcode ${GEDA_PT1_PASSCODE} \
        --registry-name ${GEDA_REGISTRY} \
        --schema ${QVI_CRED_SCHEMA} \
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
        --schema ${QVI_CRED_SCHEMA} \
        --recipient ${QVI_PRE} \
        --data @./qvi-cred-data.json \
        --rules @./rules.json \
        --time ${KLI_TIME} &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    print_lcyan "QVI Credential created for GEDA"
}
create_qvi_credential

# 17. GEDA: Issue (Grant) QVI credential to QVI
# KLI_TIME=$(kli time)
function issue_qvi_credential() {
    QVI_GRANT_SAID=$(kli ipex list \
        --name "${QAR_PT1}" \
        --alias "${QVI_MS}" \
        --passcode "${QAR_PT1_PASSCODE}" \
        --poll \
        --said)
    if [ ! -z "${QVI_GRANT_SAID}" ]; then
        print_yellow "GEDA QVI credential already issued"
        return
    fi
    SAID=$(kli vc list \
        --name "${GEDA_PT1}" \
        --passcode "${GEDA_PT1_PASSCODE}" \
        --alias "${GEDA_MS}" \
        --issued \
        --said \
        --schema ${QVI_CRED_SCHEMA})
    print_yellow "IPEX GRANTing QVI credential with\n\tSAID ${SAID}\n\tto QVI ${QVI_PRE}"
    # KLI_TIME=$(kli time)
    kli ipex grant \
        --name ${GEDA_PT1} \
        --passcode ${GEDA_PT1_PASSCODE} \
        --alias ${GEDA_MS} \
        --said ${SAID} \
        --recipient ${QVI_PRE} \
        --time ${KLI_TIME} &
    pid=$!
    PID_LIST+=" $pid"

    kli ipex grant \
        --name ${GEDA_PT2} \
        --passcode ${GEDA_PT2_PASSCODE} \
        --alias ${GEDA_MS} \
        --said ${SAID} \
        --recipient ${QVI_PRE} \
        --time ${KLI_TIME} &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST

    print_green "QVI Credential issued to QVI"
}
issue_qvi_credential

# 18. QVI: Admit QVI credential from GEDA
function admit_qvi_credential() {
    VC_SAID=$(kli vc list \
        --name "${QAR_PT1}" \
        --alias "${QVI_MS}" \
        --passcode "${QAR_PT1_PASSCODE}" \
        --said \
        --schema ${QVI_CRED_SCHEMA})
    if [ ! -z "${VC_SAID}" ]; then
        print_yellow "QVI Credential already admitted"
        return
    fi
    SAID=$(kli ipex list \
        --name "${QAR_PT1}" \
        --alias "${QVI_MS}" \
        --passcode "${QAR_PT1_PASSCODE}" \
        --poll \
        --said)
    print_yellow "Admitting QVI Credential ${SAID} from GEDA"
    # KLI_TIME=$(kli time)
    set -xe
    kli ipex admit \
        --name ${QAR_PT1} \
        --passcode ${QAR_PT1_PASSCODE} \
        --alias ${QVI_MS} \
        --said ${SAID} \
        --time "${KLI_TIME}" & 
    pid=$!
    PID_LIST+=" $pid"

    kli ipex admit \
        --name ${QAR_PT2} \
        --passcode ${QAR_PT2_PASSCODE} \
        --alias ${QVI_MS} \
        --said ${SAID} \
        --time "${KLI_TIME}" &
    pid=$!
    PID_LIST+=" $pid"

    wait $PID_LIST
    set +xe

    print_green "QVI Credential admitted"
}
admit_qvi_credential

# 19. QVI: Create and Issue LE credential to GEDA
# 20. GEDA: Admit LE credential from QVI
# 21. GEDA: Create and Issue OOR Auth & ECR Auth credential to QVI
# 22. QVI: Admit OOR Auth & ECR Auth credentials
# 23. QVI: Create and Issue OOR & ECR credentials to GEDA participants
# 24. GEDA: Admit OOR & ECR credentials from QVI

# 25. QVI: Revoke LE, OOR, ECR credentials from GEDA


print_lcyan "Full chain workflow completed"