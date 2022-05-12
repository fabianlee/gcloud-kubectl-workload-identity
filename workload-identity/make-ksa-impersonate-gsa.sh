#!/bin/bash
#
# Allow KSA 'my-wi-ksa' to impersonate the GSA service account 'gke-user' by adding IAM policy binding
SCRIPT_DIR_REL=$(dirname ${BASH_SOURCE[0]})

if [ ! -f $SCRIPT_DIR_REL/../gcloud-user.json ]; then
  echo "ERROR, you need to run 'create-gcloud-user-GSA.sh' first to create the gke-user and its json key"
  exit 3
fi

project_id=$(gcloud config get-value project)
[ -n "$project_id" ] || { echo "ERROR gcloud project not set"; exit 4; }

client_email="gcloud-user@${project_id}.iam.gserviceaccount.com"
# could have also retrieved client_email from json secret
#client_email=$(grep client_email $SCRIPT_DIR_REL/../gcloud-user.json | tr -d '",' | awk '{print $2}')
namespace="default"
KSA="my-wi-ksa"

echo "adding binding between GSA '$client_email' and KSA '$KSA' in namespace $namespace"

# add binding between GSA and KSA
set -x
gcloud iam service-accounts add-iam-policy-binding $client_email --role roles/iam.workloadIdentityUser --member serviceAccount:${project_id}.svc.id.goog[$namespace/$KSA]
