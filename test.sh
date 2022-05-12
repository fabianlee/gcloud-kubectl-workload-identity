#!/bin/bash

dep="$1"
[ -n "$dep" ] || dep=workload-identity-test
ns=default

echo ""
echo "--GCP METADATA--"
kubectl exec -it deployment/$dep -n $ns -- curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/ 2>/dev/null
res_metadata=$?

echo ""
echo "--LIST PODS--"
kubectl exec -it deployment/$dep -n $ns -- kubectl get pods -A 2>/dev/null
res_pods=$?

echo ""
echo "--LIST DAEMONSETS--"
kubectl exec -it deployment/$dep -n $ns -- kubectl get daemonset -A 2>/dev/null
res_ds=$?

echo ""
echo "--LIST REPLICASETS--"
kubectl exec -it deployment/$dep -n $ns -- kubectl get replicasets -A 2>/dev/null
res_rs=$?

echo ""
echo "--GCLOUD CLUSTERS--"
kubectl exec -it deployment/$dep -n $ns -- gcloud auth list 2>/dev/null
kubectl exec -it deployment/$dep -n $ns -- gcloud container clusters list 2>/dev/null
res_gcloud=$?

function resolve_code() {
  if [ $1 -eq 0 ]; then
    echo "OK"
  else
    echo "FAIL"
  fi
}

echo "-----------------"
echo "SUMMARY"
echo "-----------------"
echo "GCP metadata     $(resolve_code $res_metadata)"
echo "kubectl pods     $(resolve_code $res_pods)"
echo "kubectl ds       $(resolve_code $res_ds)"
echo "kubectl rs       $(resolve_code $res_rs)"
echo "gcloud clusters  $(resolve_code $res_gcloud)"
echo ""


