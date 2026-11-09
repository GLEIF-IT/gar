#!/bin/bash
set -eo pipefail

##################################################################
##                                                              ##
##  Prepare ONE parameters file for a group QVI credential.     ##
##  One GAR runs this, shares the file, and every GAR then      ##
##  runs, with that same file:                                  ##
##                                                              ##
##    create-qvi-credential.sh <file>                           ##
##    qvi-credential-grant.sh  <file>                           ##
##                                                              ##
##  Identical inputs give identical SAIDs on every GAR, which   ##
##  is what lets the members' signatures combine. The file      ##
##  fixes the datetime (generated once, here) and the QVI's     ##
##  AID (not a contact alias, which can differ per GAR).        ##
##                                                              ##
##  Usage:  prepare-qvi-credential.sh [out.json]                ##
##                                                              ##
##################################################################

schema="EBfdlu8R27Fbx-ehrqwImnK-8Cm79sqbAQ4MmvEAYqao"

PWD=$(pwd)
source "$PWD/source.sh"
set -u

read -p "Enter the LEI of the new QVI: " -r lei
read -p "Enter or Paste the AID of the new QVI (see './scripts/contacts.sh'): " -r qvi_aid

# One timestamp, generated once, used verbatim by everyone. The grant reuses it too, so there is nothing
# else to agree on (a grant's dt may equal the credential's).
dt="$(kli time | tr -d '\r\n')"

for v in lei qvi_aid dt; do
  if [ -z "${!v}" ]; then echo "${v} is empty" >&2; exit 1; fi
done
if [[ ! "${qvi_aid}" =~ ^[A-Za-z0-9_-]{44}$ ]]; then
  echo "'${qvi_aid}' does not look like an AID (44 chars qb64); use the AID, not the contact alias" >&2; exit 1
fi

out="${1:-${EXT_GAR_DATA_DIR}/qvi-${lei}-$(date -u +%Y%m%dT%H%M%S).json}"

jq -n --arg schema "${schema}" --arg lei "${lei}" --arg qvi "${qvi_aid}" --arg dt "${dt}" '
  {
    kind: "qvi",
    schema: $schema,
    data: {LEI: $lei},
    recipient: $qvi,
    createTime: $dt,
    grantTime: $dt
  }' > "${out}"

echo
cat "${out}"
echo
echo "Wrote ${out}"
echo "Send this file to the other GAR(s). Everyone then runs:"
echo "  ./scripts/create-qvi-credential.sh <file>"
echo "  ./scripts/qvi-credential-grant.sh  <file>"
