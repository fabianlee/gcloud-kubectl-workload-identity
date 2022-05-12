#!/bin/bash
#
# loads GCP service account json key into cluster as secret
# available via pods that need to authenticate into gcloud
#
# https://cloud.google.com/kubernetes-engine/docs/tutorials/authenticating-to-cloud-platform#kubectl
#
SCRIPT_DIR_REL=$(dirname ${BASH_SOURCE[0]})

json_file="$1"
[ -n "$json_file" ] || json_file="$SCRIPT_DIR_REL/../gcloud-user.json"

if [ ! -f "$json_file" ]; then
  echo "ERROR could not find json key file $json_file"
  echo ""
  echo "Usage: key.json"
  echo "Example: ../gcloud-user.json"
  exit 3
fi

# load GSA json secret into default namespace
kubectl create secret generic gke-key -n default --from-file=key.json=$json_file

# show
kubectl get secret gke-key -n default
