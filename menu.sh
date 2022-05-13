#!/bin/bash
#
# Wizard to show available actions
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

# visual marker for task
declare -A done_status

# BASH does not support multi-dimensional/complex datastructures
# 1st column = action
# 2nd column = description
menu_items=(
  "gke-wi-check,Validate workload identity status of GKE cluster"
  ""
  "generic,Deploy generic image"
  "simpleksa,Deploy image running as simple KSA"
  "annotatedksa,Deploy image running as KSA which is annotated with GSA"
  "jsonsecret,Deploy image with GCP json secret mounted"
  "workloadid,Deploy image running as KSA with mapping to GSA"
  ""
  "deployments,Validate health of deployments, KSA, GSA role"
  ""
  "generic-test,Rest generic access to kubectl and gcloud"
  "simpleksa-test,Test access to kubectl and gcloud"
  "annotatedksa-test,Test access to kubectl and gcloud"
  "jsonsecret-test,Test access to kubectl and gcloud"
  "workloadid-test,Test access to kubectl and gcloud"
  ""
  "ksa-can-i,Test KSA permissions using kubectl can-i"
  ""
  "teardown,remove deployments, KSA, and KSA/GSA binding"
)
#  "gcloud-user,Create GCP service account 'gcloud-user'"

function showMenu() {
  echo ""
  echo ""
  echo "==========================================================================="
  echo " MAIN MENU for $kubectl_context"
  echo "==========================================================================="
  echo ""
  
  for menu_item in "${menu_items[@]}"; do
    # skip empty lines
    [ -n "$menu_item" ] || { printf "\n"; continue; }

    menu_id=$(echo $menu_item | cut -d, -f1)
    # eval done so that embedded variables get evaluated (e.g. MYKUBECONFIG)
    label=$(eval echo $menu_item | cut -d, -f2-)
    printf "%-18s %-60s %-10s\n" "$menu_id" "$label" "${done_status[$menu_id]}"

  done
  echo ""
} # showMenu


GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'
NF='\033[0m'
function echoGreen() {
  echo -e "${GREEN}$1${NC}"
}
function echoRed() {
  echo -e "${RED}$1${NC}"
}
function echoYellow() {
  echo -e "${YELLOW}$1${NC}"
}

function ensure_binary() {
  binary="$1"
  install_instructions="$2"
  binpath=$(which $binary)
  if [ -z "$binpath" ]; then
    echo "ERROR you must install $binary before running this wizard"
    echo "$install_instructions"
    exit 1
  fi
}

function check_prerequisites() {

  if [ ! -f gcloud-user.json ]; then
    echo "ERROR you must create the GCP 'gcloud-user' service account before running these actions, run './create-gcloud-user-GSA.sh'"
    exit 4
  fi

  if [ -z "$KUBECONFIG" ]; then
    echo "ERROR you must have the environment variable 'KUBECONFIG' defined before running these actions"
    exit 5
  fi

  # make sure binaries are installed 
  ensure_binary gcloud "install https://cloud.google.com/sdk/docs/install"
  ensure_binary kubectl "install https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/"
  #ensure_binary yq "download from https://github.com/mikefarah/yq/releases"
  #ensure_binary jq "run 'sudo apt install jq'"

  # show binary versions
  # on apt, can be upgraded with 'sudo apt install --only-upgrade google-cloud-sdk -y'
  gcloud --version | grep 'Google Cloud SDK'
  kubectl version --short 2>/dev/null
  #yq --version
  #jq --version

  # check for gcloud login context
  gcloud projects list > /dev/null 2>&1
  [ $? -eq 0 ] || gcloud auth login --no-launch-browser
  gcloud auth list

} # check_prerequisites


###### MAIN ###########################################


check_prerequisites "$@"

# export so it can be used as envsubst templating variable
export project_id=$(gcloud config get-value project)
echo "GCP project_id=$project_id"

kubectl_context=$(kubectl config current-context)
echo "Kubetctl current context: $kubectl_context"

# loop where user can select menu items
lastAnswer=""
answer=""
while [ 1 == 1 ]; do
  showMenu
  test -t 0
  if [ ! -z $lastAnswer ]; then echo "Last action was '${lastAnswer}'"; fi
  read -p "Which action (q to quit) ? " answer
  echo ""

  case $answer in


    gke-wi-check)
      clusters=$(gcloud container clusters list --format="csv[no-heading](name,location)")
      IFS=$'\n'
      for cluster in $clusters ; do
        cname=$(echo $cluster | cut -d, -f1)
        echo "----CLUSTER $cname-----------------"

        # if location has 2 dashes, then it is zonal GKE cluster.  else regional
        clocation=$(echo $cluster | cut -d, -f2)
        if [[ $clocation =~ .*-.*-.* ]]; then
          location_flag=$(echo "--zone=$clocation")
        else
          location_flag=$(echo "--region=$clocation")
        fi

        #set -x
        wi_identity=$(gcloud container clusters describe $cname $location_flag --format="value(workloadIdentityConfig.workloadPool)")
        if [ -z "$wi_identity" ]; then
          echo "WARNING!!! workload identity not enabled for cluster $cname, many of these tests will not work as expected !!!!!!!!!!!!!!!!!!"
        else
          echo "workload identity for $cname: $wi_identity"
          nodepool_name=$(gcloud container node-pools list --cluster=$cname $location_flag --format="value(name)")

          pool_wi_mode=$(gcloud container node-pools describe $nodepool_name --cluster=$cname $location_flag --format="value(config.workloadMetadataConfig.mode)")
          if [ -z "$pool_wi_mode" ]; then
            echo "WARNING!!! node pool does not have workload metadata mode set, many of these tests will not work as expected until the nodepool is rebuilt with workload identity enabled!!!!!"
          else
            echo "workload mode for nodepool $nodepool_name is $pool_wi_mode"
          fi

        fi
        #set +x
      done

      retVal=0
      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    gcloud-user)
      set -x
      ./create-gcloud-user-GSA.sh $project_id
      retVal=$?
      set +x

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    generic)
      set -x
      kubectl apply -f generic-test/generic-test.yaml 2>/dev/null
      retVal=$?
      set +x

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    simpleksa)
      set -x
      kubectl apply -f kubectl-with-simple-ksa/my-ksa.yaml 2>/dev/null
      kubectl apply -f kubectl-with-simple-ksa/kubectl-ksa-test.yaml 2>/dev/null
      retVal=$?
      set +x

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    annotatedksa)
      set -x
      envsubst < kubectl-with-annotated-ksa/my-ksa-annotated.yaml | kubectl apply -f - 2>/dev/null
      kubectl apply -f kubectl-with-annotated-ksa/kubectl-ksa-annotated-test.yaml 2>/dev/null
      retVal=$?
      set +x

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    jsonsecret)
      set -x
      gcloud-with-gsa-secret/load_gcloud_secret_into_k8s.sh
      kubectl apply -f gcloud-with-gsa-secret/gcloud-gsa-test.yaml 2>/dev/null
      retVal=$?
      set +x

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    workloadid)
      set -x
      envsubst < workload-identity/my-wi-ksa.yaml | kubectl apply -f - 2>/dev/null
      workload-identity/make-ksa-impersonate-gsa.sh
      kubectl apply -f workload-identity/workload-identity-test.yaml 2>/dev/null
      retVal=$?
      set +x

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    teardown)
      set -x
      kubectl delete -f generic-test/generic-test.yaml 2>/dev/null

      kubectl delete -f kubectl-with-simple-ksa/my-ksa.yaml 2>/dev/null
      kubectl delete -f kubectl-with-simple-ksa/kubectl-ksa-test.yaml 2>/dev/null

      envsubst < kubectl-with-annotated-ksa/my-ksa-annotated.yaml | kubectl delete -f - 2>/dev/null
      kubectl delete -f kubectl-with-annotated-ksa/kubectl-ksa-annotated-test.yaml 2>/dev/null

      kubectl delete -f gcloud-with-gsa-secret/gcloud-gsa-test.yaml 2>/dev/null
      kubectl delete secret gke-key -n default 2>/dev/null

      workload-identity/remove-ksa-impersonate-gsa.sh
      envsubst < workload-identity/my-wi-ksa.yaml | kubectl delete -f - 2>/dev/null
      kubectl delete -f workload-identity/workload-identity-test.yaml 2>/dev/null
      set +x

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    deployments)
      set -x
      kubectl get deployments 2>/dev/null

      kubectl get sa 2>/dev/null

      gcloud iam service-accounts get-iam-policy \
      --flatten="bindings[].members" \
      --format="table(bindings.role, bindings.members)" \
      gcloud-user@${project_id}.iam.gserviceaccount.com

      gcloud projects get-iam-policy my-gkeproj1-10941 \
      --flatten="bindings[].members" \
      --format='table(bindings.role)' \
      --filter="bindings.members:gcloud-user@${project_id}.iam.gserviceaccount.com"

      retVal=$?
      set +x
      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    generic-test)
      set -x
      ./test.sh generic-test
      retVal=$?
      set +x

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    simpleksa-test)
      set -x
      ./test.sh kubectl-ksa-test
      retVal=$?
      set +x

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    annotatedksa-test)
      set -x
      ./test.sh kubectl-ksa-annotated-test
      retVal=$?
      set +x

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    jsonsecret-test)
      set -x
      ./test.sh gcloud-gsa-test
      retVal=$?
      set +x

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    workloadid-test)
      set -x
      ./test.sh workload-identity-test
      retVal=$?
      set +x

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    ksa-can-i)
      echo "--- service account my-ksa ---"
      echo "should be able to list pods"
      kubectl auth can-i list pods --namespace default --as system:serviceaccount:default:my-ksa 2>/dev/null
      echo "should NOT be able to list daemonset"
      kubectl auth can-i list daemonsets --namespace default --as system:serviceaccount:default:my-ksa 2>/dev/null
      echo "should be able to list replicasets"
      kubectl auth can-i list replicasets --namespace default --as system:serviceaccount:default:my-ksa  2>/dev/null

      echo ""
      echo "--- service account my-ksa-annotated ---"
      echo "should be able to list pods"
      kubectl auth can-i list pods --namespace default --as system:serviceaccount:default:my-ksa-annotated 2>/dev/null
      echo "should be able to list daemonsets"
      kubectl auth can-i list daemonsets --namespace default --as system:serviceaccount:default:my-ksa-annotated 2>/dev/null
      echo "should NOT be able to list replicasets"
      kubectl auth can-i list replicasets --namespace default --as system:serviceaccount:default:my-ksa-annotated 2>/dev/null

      echo ""
      echo "--- service account my-wi-ksa ---"
      echo "should be able to list pods"
      kubectl auth can-i list pods --namespace default --as system:serviceaccount:default:my-wi-ksa 2>/dev/null
      echo "should be able to list daemonsets"
      kubectl auth can-i list daemonsets --namespace default --as system:serviceaccount:default:my-wi-ksa 2>/dev/null
      echo "should NOT be able to list deployments"
      kubectl auth can-i list deployments --namespace default --as system:serviceaccount:default:my-wi-ksa 2>/dev/null
      retVal=0
      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    q|quit|0)
      echo "QUITTING"
      exit 0;;
    *)
      echoRed "ERROR that is not one of the options, $answer";;
  esac

  lastAnswer=$answer
  echo "press <ENTER> to continue..."
  read -p "" foo

done




