#!/bin/bash
set -eo pipefail

##################################################################
##                                                              ##
##  Prepare ONE parameters file for a group OOR or ECR auth     ##
##  credential. One GAR runs this, shares the file, and every   ##
##  GAR then runs, with that same file:                         ##
##                                                              ##
##    create-oor-auth-credential.sh <file>   (or create-ecr-)   ##
##    grant-oor-auth-credential.sh  <file>   (or grant-ecr-)    ##
##                                                              ##
##  Identical inputs give identical SAIDs on every GAR, which   ##
##  is what lets the members' signatures combine. The file      ##
##  fixes the datetime (generated once, here) so nobody has to ##
##  copy it.                                                    ##
##                                                              ##
##  Usage:  prepare-auth-credential.sh oor|ecr [out.json]       ##
##                                                              ##
##################################################################

kind="${1:-}"
case "${kind}" in
  oor) schema="EKA57bKBKxr_kN7iN5i7lMUxpMG-s19dRcmov1iDxz-E"; role_key="officialRole";
       role_prompt="Enter requested official role: " ;;
  ecr) schema="EH6ekLjSr8V32WyFbGe1zXjTzFs9PkTYmupJ9H65O14g"; role_key="engagementContextRole";
       role_prompt="Enter requested engagement context role: " ;;
  *) echo "usage: prepare-auth-credential.sh oor|ecr [out.json]" >&2; exit 2 ;;
esac

PWD=$(pwd)
source "$PWD/source.sh"
set -u

echo "Use 'kli vc list' to determine the SAID of the legal entity (LE) credential issued to this LE by the QVI"
read -p "Enter the SAID of the legal entity (LE) credential issued to this LE by the QVI: " -r le_said
read -p "Enter your LEI : " -r lei
read -p "Enter or Paste the AID of the recipient of the $(echo "${kind}" | tr a-z A-Z) credential: " -r person_aid
read -p "Enter requested person legal name: " -r person_name
read -p "${role_prompt}" -r role
read -p "Enter or Paste the AID of the QVI to authorize with this AUTH credential: " -r qvi_aid

# One timestamp, generated once, used verbatim by everyone. The grant reuses it too, so there is nothing
# else to agree on (a grant's dt may equal the credential's).
dt="$(kli time | tr -d '\r\n')"

for v in le_said lei person_aid person_name role qvi_aid; do
  if [ -z "${!v}" ]; then echo "${v} is empty" >&2; exit 1; fi
done

slug=$(echo "${person_name}" | tr -cs 'A-Za-z0-9' '-' | sed 's/^-*//; s/-*$//' | tr A-Z a-z)
out="${2:-${INT_GAR_DATA_DIR}/${kind}-auth-${slug}-$(date -u +%Y%m%dT%H%M%S).json}"

jq -n --arg kind "${kind}" --arg schema "${schema}" --arg le "${le_said}" \
      --arg aid "${person_aid}" --arg lei "${lei}" --arg name "${person_name}" \
      --arg rk "${role_key}" --arg role "${role}" \
      --arg qvi "${qvi_aid}" --arg dt "${dt}" '
  {
    kind: $kind,
    schema: $schema,
    leSaid: $le,
    data: ({AID: $aid, LEI: $lei, personLegalName: $name} + {($rk): $role}),
    recipient: $qvi,
    createTime: $dt,
    grantTime: $dt
  }' > "${out}"

echo
cat "${out}"
echo
echo "Wrote ${out}"
echo "Send this file to the other GAR(s). Everyone then runs:"
echo "  ./scripts/create-${kind}-auth-credential.sh <file>"
echo "  ./scripts/grant-${kind}-auth-credential.sh  <file>"
