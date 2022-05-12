#!/bin/bash

echo "--LIST K8S CLUSTERS--"
kubectl exec -it deployment/gcloud-gsa-test -n default -- gcloud container clusters list

echo ""
echo "--LIST VM INSTANCES--"
kubectl exec -it deployment/gcloud-gsa-test -n default -- gcloud compute instances list

