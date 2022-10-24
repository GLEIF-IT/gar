
# GLEIF Authorized Representative (GAR)

This package contains documentation and Bash shell scripts needed to use the KERIpy command line tool (`kli`) to
participate as a GLEIF Authorized Representative (GAR) as a member of the GLEIF External Autonomic Identifier (AID) or
the GLEIF Internal Autonomic Identifier (AID) 

## Repository Layout
This repository contains documentation in the `./docs` directory and Bash shell scripts in the `./scripts` directory.  The 
scripts make it easy to use the KERI command line tool `kli` to perform all functions required of a GAR.  It utilizes the KERI
docker image `gleif/keri:0.6.7` with mounts to local directories to minimize the requirements on the local system.  

## Getting Started
The steps needed to bootstrap your system are described in [Getting Started](./docs/getting-started.md).  After following
the steps described in that document you will have a KERI datastore and keystore encrypted using a randomly generated passcode
that is automatically stored in your Mac keychain.  

From there you will be ready to join and participate in a Group Multisig AID as described in [Creating Group AID](./docs/creating-group-aid.md).