
# Getting Started
This document describes the steps required to bootstrap your system using the scripts in this repository to act as 
a GLEIF Authorized Representative (GAR) and member of either the GLEIF External AID or GLEIF Internal AID, both of which
will be KERI group multisig AIDs.

It uses Docker to run a customized `kli` command that mounts the local `$HOME/.gar` repo as a data directory for the `kli` command.


## Initial Installation
The steps described in this section only need to be performed once to prepare your system to run the required software to
perform as a GAR.


### Prerequisites
The software in this repository is designed to run on MacBook Pro laptops with macOS Monterey (ver 12.6) or higher.

The following five software packages are required to execute the scripts in this repository:

- Homebrew (brew) - The Missing Package Manager for macOS
- Docker Desktop on Mac
- Bash - the Bourne Again SHell
- jq - `sed` for JSON data
- git - distributed version control system

Installation instructions for Homebrew (`brew`) can be found here: https://brew.sh.
Installation instructions for Docker Desktop can be found here: https://docs.docker.com/desktop/install/mac-install/.  
Bash/Zsh should be installed by default on your MacOS computer.  
Installation instructions for `jq` can be found here: https://stedolan.github.io/jq/download, utilize the brew command.
Installation instructions for `git` can be found here: https://git-scm.com/download/mac, utilize the brew command.

### System Setup
The scripts in this package rely on the KERIpy docker image `weboftrust/keri` hosted on docker hub.  The first step is to execute the
following script once, the first time you prepare to use this package, to set up the AID inception configuration files:

```bash
$ ./scripts/prepare.sh
```

The output should resemble:

```bash
enc-notifications: Pulling from weboftrust/keri
Digest: sha256:5dead12388be0a814c00044369a2dc52465318af329b1c7f4956810c83ae4e6c
Status: Image is up to date for weboftrust/keri:enc-notifications
docker.io/weboftrust/keri:enc-notifications

```

This script will perform a docker pull for the KERIpy image as well as creating your local directory that stores the
datastore, keystore and configuration information generated as a GAR.  You will not need to run this script again.

The final step in system setup is to edit the `scripts/env.sh` initialization script under the directory 
(external or internal) and role you are working as and set two values used as exported environment variables in the 
rest of the scripts.  

At the top of the `scripts/env.sh` file there are two exported environment variables:

```bash
# Change to the name you want to use for your local database environment.
export EXT_GAR_NAME="External GAR"

# Change to the name you want for the alias for your local External GAR AID
export EXT_GAR_ALIAS="John Doe"
```

or 

```bash
# Change to the name you want to use for your local database environment.
export INT_GAR_NAME="Internal GAR"

# Change to the name you want for the alias for your local Internal GAR AID
export INT_GAR_ALIAS="John Doe"
```

Change these values in `scripts/env.sh` to the names you want to use for your database directory and local AID alias respectively.
These values are local to you and not exposed to anyone else so they just need to be values that make sense for you.  We recommend
leaving `EXT_GAR_NAME` as it currently is and changing `EXT_GAR_ALIAS` to your full name.


## Environment Initialization
Each time you wish to perform a function as a GAR you must initialize your shell environment to gain access to your 
keystore and the KERIpy `kli` command.  You should always start with a new Terminal (or new shell in an existing terminal application)
and source the following script from the root directory of this repository using this command:

```bash
$ source ./source.sh
```

This script performs several functions.  The first time it is sourced it will create a random passcode and a random
salt and store both in your Mac Keychain.  The random passcode is use to encrypt your keystore and must be provided for all
subsequent calls to the `kli` tool (the rest of the scripts do this for you).  The salt is used to initialize the hierachical
deterministic keychain of private keys for your wallet.  This can be used to recover your set of private keys in the event
of a keystore loss.  All subsequent executions of this script will ensure the passcode and salt are stored in your keychain
and will not recreate them

The `source.sh` script also initializes several environment variables (via `scripts/env.sh`) used by the rest of the scripts as well
as a Bash function for `kli` that executes the docker image as a throw away container for each command run.

## Create Your Local AID
As a GLEIF Authorized Representative you will be a member of the group multisig AID for either the GLEIF External AID or
the GLEIF Internal AID.  To participate as a member of a group multisig, you must first create your local AID that will contribute 
its public key to the set of public keys that comprise the group mutlsig.  After initializing your system and sourcing `source.sh` the
next step is to execute the following script to create your local AID:

```bash
$ ./scripts/create-local-aid.sh
```

The output from this script should resemble:

```bash
Please select witness pool:
1) Pool 1
2) Pool 2
3) Test Pool
Enter pool number: 
```
Select the correct witness pool for your purpose and press *ENTER*. Pool 1 and 2 are production, Test Pool is staging.
The output after you select your pool will resemble:

```bash
KERI Keystore created at: /usr/local/var/keri/ks/External GAR
KERI Database created at: /usr/local/var/keri/db/External GAR
KERI Credential Store created at: /usr/local/var/keri/reg/External GAR
        aeid: BHMKPSkyCN_MkEmK_LziMX9kYj3jgoeoS6oqoNhXpacJ
Loading 11 OOBIs...
http://139.99.193.43:5623/oobi?name=OC-AU-OVH-test succeeded
http://20.3.144.86:5623/oobi?name=NA-US-AZR-test succeeded
http://47.242.47.124:5623/oobi?name=AS-CN-ALI-test succeeded
http://49.12.190.139:5623/oobi?name=EU-DE-HTZ-test succeeded
https://weboftrust.github.io/oobi/EBNaNu-M9P5cgrnfl2Fvymy4E_jvxxyjb70PRtiANlJy succeeded
https://weboftrust.github.io/oobi/EBfdlu8R27Fbx-ehrqwImnK-8Cm79sqbAQ4MmvEAYqao succeeded
https://weboftrust.github.io/oobi/EEy9PkikFcANV1l7EHukCeXqrzT1hNZjGlUk7wuMO5jw succeeded
https://weboftrust.github.io/oobi/EH6ekLjSr8V32WyFbGe1zXjTzFs9PkTYmupJ9H65O14g succeeded
https://weboftrust.github.io/oobi/EKA57bKBKxr_kN7iN5i7lMUxpMG-s19dRcmov1iDxz-E succeeded
https://weboftrust.github.io/oobi/EMhvwOlyEJ9kN4PrwCpr9Jsv7TxPhiYveZ0oP3lJzdEi succeeded
https://weboftrust.github.io/oobi/ENPXp1vQzRF6JwIuS-mp2U8Uf1MoADoP_GqQ62VsDZWY succeeded
Waiting for witness receipts...
Prefix  ECxoc9W1og1e6SjYAJbewsr48yI78tFOwESaqDdYAsQJ
        Public key 1:  DPuz8s6nR_nV-p_7cBssqDNkDc0iJfs2uP6n-02H0ZHE
Alias:  John Doe
Identifier: ECxoc9W1og1e6SjYAJbewsr48yI78tFOwESaqDdYAsQJ
Seq No: 0
Witnesses:
Count:          4
Receipts:       4
Threshold:      3
Public Keys:
        1. DPuz8s6nR_nV-p_7cBssqDNkDc0iJfs2uP6n-02H0ZHE
```

A few items are important to understand.  You should see that the path of the Keystore, Datastore and Credential Store
all end with the name specified in the `EXT_GAR_NAME` environment variable.  In addition, all the paths are rooted at `/usr/local/var/keri`
in the output.  That is because we are using a docker container to execute the commands mounted with `/usr/loca/var/keri` to
the local path `$HOME/.gar`.  

Some values that will be different in your output to the sample here include the witness IP addresses and name parameters,
the number of witnesses and the AID (Prefix:) and Public Key values.  The value for "Alias" should be the value you specified
in `source.sh` as the `EXT_GAR_ALIAS` environment variable.

If at any time you want to see this output again to see the current state of your AID you can execute the following:

```bash
$ ./scripts/status.sh
```

## Next Steps
Now that your system is initialized, you are ready to proceed to the next step in the process of being a GAR, ["Create GLEIF Group Multisig AID"](creating-group-aid.md).
