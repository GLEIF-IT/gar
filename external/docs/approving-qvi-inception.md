
# Approving QVI Inception Events.

This document is intended for GLEIF External Authorized Representatives (External GARs) in their daily interactions with
Qualified vLEI Issuers (QVI).  It describes the steps required to authenticate QVI Authorized Representatives (QARs) and 
approve the creation of their group multisig AID by participating in the creation of a KERI interaction event that contains
a seal of the inception event for the QVI Group Multisig AID.


## Step Overview

At a high level the steps to perform a QVI inception event are as follows.

1. Get the identifier prefix of the GLEIF External AID.
2. Create a delegated multisig inception configuration with the delegation property set to the GLEIF External AID.
3. As the QVI participants, perform a delegated multisig inception with the delegated multisig inception configuration.
4. As the GAR participants, approve the delegated multisig inception.

# Step Details

TODO: modify KIMS or Citadel to create a valid delegation inception configuration JSON.

1. Get the identifier prefix of the GLEIF External AID.
    - Call this identifier GEDA_PRE for now.
2. Create a delegated multisig inception configuration. 
    - This will require the following:
        - GLEIF External AID.
        - The AID for each participating QVI multisig group member.
        - The AID for each witness of the QVI multisig group.
        - The desired threshold of accountable duplicity (TOAD).
        - The desired signing and rotation weights for each QVI multisig group member.
    - Create a valid configuration file based on the following example:
    ```json
    {
        "delpre": "${GEDA_PRE}",
        "aids": [
            "${QVI_PT1_PRE}",
            "${QVI_PT2_PRE}"
        ],
        "transferable": true,
        "wits": ["${WIT_PRE}"],
        "toad": 1,
        "isith": "2",
        "nsith": "2"
    }
    ```
3. Using appropriate QVI software, or the KERIpy KLI command line tool, perform a multisig inception event with each
participant in the QVI multisig group.

4. 


