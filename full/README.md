# Full vLEI Chain Script Demo

The demonstration scripts in this directory are an illustration of the steps in the QVI qualification dry run process. There are three demonstrations:
1. `full-chain.sh` - this shows using a local, non-containerized workflow using only the KLI (KERIpy).
2. `full-chain-docker-kli_only.sh` - this shows using a fully containerized workflow using only the KLI (KERIpy).
3. `full-chain-docker-kli_and_keria.sh` - this shows a containerized workflow using KLI for the GAR parts and KERIA for the QVI parts.

## Dependencies

- NodeJS - remember to do `npm install` in the `full` directory to install 
- [`tsx`](https://tsx.is/getting-started) - TypeScript Execute - for easily running Typescript files like a shell script.
  - This MUST be installed globally with `npm i -g tsx` in order to run properly.
