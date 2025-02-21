# Abbreviated Steps

# GARs
GLEIF_HOME should be exported in your user profile environment to be the directory with the `gar` repo, this repository.

Then, from within either the `external/` or `internal/` directories:

1. `./scripts/prepare.sh` - makes .gar dirs, copies config.
2. Change `{external,internal}/scripts/env.sh` to have your name.
3. `source ./source.sh`   - creates keychain secrets and changes `kli` command.
4. `./scripts/create-local-aid.sh` and use Test Pool for `scripts/test-incept-pool-1.json` and `scripts/keri/cf/test-ext-gar-config.json`
5. `./scripts/generate-oobi.sh`
6. `./scripts/generate-challenge.sh` - copy the 12 words and send to responder
7. `./scripts/respond-to-challenge.sh` - receive 12 words and respond to challenger
8. `./scripts/multisig-shell.sh`
9. add multisig participants
  - add local <your alias>
  - add participant <other person alias>
11. add witnesses 
  - add witness EU-DE-HTZ-test
  - add witness OC-AU-OVH-test
  - add witness NA-US-AZR-test
  - add witness AS-CN-ALI-test
12. save `/data/my-multisig-aid.json`
    or show it with "show"
13. `./scripts/multisig-incept.sh`
    Name should be equal to EXT_GAR_AID_ALIAS, usually "GLEIF External AID". Use the multisig configuration you saved earlier. It should be in the `$GLEIF_HOME/gar/external/data` directory.
14. Then have the other participant do `./scripts/multisig-join.sh` and name the AID the same name.
15. Generate an OOBI for the delegation proxy to use.
  - Generate an OOBI for the GLEIF External AID with:
    - `./scripts/generate-oobi.sh` and select the "GLEIF External AID" option.
    - Keep a copy of this OOBI for the proxy setup step next.

# QVI
16. Set up the proxy for QVI delegated inception (single-sig).
  - Incept the proxy in a **separate terminal window**. 
    - The proxy allows the qvi delegate identifier to communicate to the delegator prior to the delegator approving the delegate. This is why it is called a proxy.
    - A proxy is not necessary if you are doing multisig delegation because the multisig group essentially uses the single sig participants as communication proxies.

  - Create the QVI habery/keystore **(separate terminal window)**:   
    - ```bash
      kli init --name qvi \
          --salt 0ACbOs9VqHVnZPwRR42xIFmH \
          --passcode r2zXnzdOa1Dd6m4U61Ag3 \
          --config-dir "${GLEIF_HOME}"/gar/external/config \
          --config-file staging-bootstrap-config.json
      ```
  
  - Resolve the OOBI of the GLEIF External AID for the QVI Habery **(separate terminal window)**:
    ```bash
    kli oobi resolve --name qvi \
        --passcode r2zXnzdOa1Dd6m4U61Ag3 \
        --oobi-alias "GLEIF External AID" \
        --oobi http://47.242.47.124:5623/oobi/ECwSVfPF6jX6xIuJn62ijmT0gA-mhzsW6NfCvQwTgjVd/witness
    ```

  - Incept the proxy AID in the QVI Habery **(separate terminal window)**:
    - ```bash
      kli incept --name qvi \
        --passcode r2zXnzdOa1Dd6m4U61Ag3 \
        --alias proxy \
        --file "${GLEIF_HOME}"/gar/external/config/proxy-incept-config.json
      ```    
17. Incept a QVI delegated AID as a single-sig AID for simplicity (instead of multi-sig).
  - Take the identifier prefix of the GLEIF External AID and put it in the "delpre" field of the delegated identifier inception config. See `$GLEIF_HOME/gar/external/config/qvi-incept-single-sig.json` for an example.
  - Incept the single-sig, delegated QVI AID, via the proxy **(separate terminal window)**:
    - ```bash 
      kli incept --name qvi \
        --passcode r2zXnzdOa1Dd6m4U61Ag3 \
        --alias qvi \
        --proxy proxy \
        --file "${GLEIF_HOME}"/gar/external/config/qvi-incept-single-sig.json
      ```  
18. GARs confirm the delegation with:
  - `./scripts/kli.sh delegate confirm --alias "GLEIF External AID" --interact`
  - do this for both GARs
19. Then perform an OOBI resolution between the GARs and the QVI. 
  - Generate the QVI OOBI **(separate terminal window)**:
  - `kli oobi generate --name qvi --passcode r2zXnzdOa1Dd6m4U61Ag3 --alias qvi1 --role witness`
  - Resolve this OOBI for each GAR with `./scripts/resolve-oobi.sh`
20. Create a credential registry for the GARs:
  - `./scripts/create-registry.sh` with GAR 1. Say "y" to creating a nonce and send it to the other GAR.
  - the other GAR should use the provided nonce with `./scripts/create-registry.sh`
21. Then Issue the QVI credential with:
  - `./scripts/create-qvi-credential.sh`
  - Use the LEI for your target organization, the alias of the QVI OOBI you resolved, and the same date time across both QVIs
22. Present (GRANT) the QVI credential with:
  - `./scripts/qvi-grant-credential.sh`  
  - Do this from both of the GARs.
23. Admit the QVI credential from the QVI after polling for it:
  - ```bash
    kli ipex list --name qvi \
        --passcode r2zXnzdOa1Dd6m4U61Ag3 \
        --alias qvi \
        --type 'grant' \
        --poll
    ```
  - This will show the credential GRANT SAID on the screen which is needed for the next step.
  - ```bash
    kli ipex admit --name qvi \
        --passcode r2zXnzdOa1Dd6m4U61Ag3 \
        --alias qvi \
        --said ELSgR5Aow_aCXeXbumy5CdDeOzIR-LbYTWRJk7IMA5ZZ
    ```    
24. Then create a legal entity (LE) identifier using the GIDA internal scripts.
  In a separate terminal:
  - Both GIDAs: `cd $GLEIF_HOME/gar/internal`
  - Both: `./scripts/prepare/sh`
  - Both: `source source.sh`
  - Both: `./scripts/create-local-aid.sh` as before, for each GAR
  - Both: `./scripts/generate-oobi.sh`
  - Both: `./scripts/resolve-oobi.sh`
  - GIDA1: `./scripts/multisig-shell.sh` to create the GIDA multisig config.
  - GIDA1: `./scripts/multisig-incept.sh` to initiate GIDA multisig inception.
  - GIDA2: `./scripts/multisig-join.sh` to join the GIDA multisig inception from the other participant.
25. Then have the QVI resolve the OOBI of the LE (GIDA)
  - GIDA: `./scripts/generate-oobi.sh` (then select the GLEIF Internal AID)
  - QVI: `./scripts/resolve-oobi.sh`
26. Then create the QVI registry with:
  - In the QVI-specific terminal:
  ```bash
  kli vc registry incept --name qvi \
    --alias qvi \
    --passcode r2zXnzdOa1Dd6m4U61Ag3 \
    --registry-name le-registry \
    --nonce AE5a9CsYy4UMMv_95-M4a_A64KAOeV_zilZre6VOXNyl \
    --usage "LE creds"
  ```
27. Then create the legal entity ACDC credential data JSON by copying the data/qvi-data.json to data/le-data.json
28. Then create the qvi-edge.json and SAIDify it with:
  - `kli saidify-f ./data/qvi-edge.json`
    - The file will look like this:
    ```json
    {
        "d": "EN0F5DZSEVZ31XnXvjWRpj95ETapK-88E9TYK8N9GLaR", 
        "qvi": {
            "n": "${QVI_CRED_SAID}", 
            "s": "EBfdlu8R27Fbx-ehrqwImnK-8Cm79sqbAQ4MmvEAYqao"
        }
    }
    ```
29. Issue the credential with, changing the recipient to your LE (GIDA) multisig AID:
  ```bash
  kli vc create --name qvi --alias qvi --passcode r2zXnzdOa1Dd6m4U61Ag3 --registry-name le-registry \
        --schema ENPXp1vQzRF6JwIuS-mp2U8Uf1MoADoP_GqQ62VsDZWY \
        --recipient EI__7tAZS8MAtpu4d6KVMncBb_y1IMClftNL-pVh6Tce \
        --data @./data/le-data.json \
        --edges @./data/qvi-edge.json \
        --rules @./data/rules.json
  ```                
30. Then present (IPEX Grant) the credential with:
```bash
kli ipex grant --name qvi \
    --passcode r2zXnzdOa1Dd6m4U61Ag3 \
    --alias qvi \
    --said ELySVeEQiinw8ss9ThaCwgIWiXcVfQ2_d6fvne9m0FF2 \
    --recipient EI__7tAZS8MAtpu4d6KVMncBb_y1IMClftNL-pVh6Tce
```
31. Then admit the credential as the two GIDA participants:
  - GIDA1: `./scripts/admit-le-credential.sh`