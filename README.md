# Testing access to kubectl and gcloud from inside GKE container

This project is for testing access to kubectl and gcloud from within a K8S GKE container.  The [google-cloud-cli image](https://console.cloud.google.com/gcr/images/google.com:cloudsdktool/GLOBAL/google-cloud-cli) will provide us access to the kubectl+gcloud binary, but you still need to provide credentials.

We will test the following scenarios:

Test | description
---|---
generic-test | vanilla deployment of container that has gcloud+kubectl binaries, run as default
kubectl-with-simple-ksa | run as simple Kubernetes Service Acct (KSA)
kubectl-with-annotated-ksa | run as KSA with GSA annotation (but not GSA binding)
gcloud-with-gsa-secret | run as default, but has mounted Google Service Acct (GSA) json secret
workload-identity | using workload identity. binding created between KSA and GSA, run as KSA

## Prerequisites

* GKE Cluster enabled with workload identity
* gcloud binary
* kubectl binary
* KUBECONFIG environment variable exported
* kubecontext set to cluster you wish to target

## Run the Example

```
# show default kubeconfig and context
echo $KUBECONFIG
kubectl config current-context

# run menu that will take you through steps
git clone https://github.com/fabianlee/gcloud-kubectl-workload-identity.git
cd gcloud-kubectl-workload-identity.git
./menu.sh
```

## Run each step in menu

Going from top to bottom, run each action shown to deploy and then test each gcloud/kubectl access method.

```
===========================================================================
 MAIN MENU for gke_my-gkeproj1-xxx_us-east1_cluster1
===========================================================================

gke-wi-check     Validate workload identity status of GKE cluster                         

generic          Deploy generic image                                                     
simpleksa        Deploy image running as simple KSA                                       
annotatedksa     Deploy image running as KSA which is annotated with GSA                  
jsonsecret       Deploy image with GCP json secret mounted                                
workloadid       Deploy image running as KSA with mapping to GSA                          

deployments      Validate health of deployments, KSA, GSA role                            

generic-test     Rest generic access to kubectl and gcloud                                
simpleksa-test   Test access to kubectl and gcloud                                        
annotatedksa-test Test access to kubectl and gcloud                                        
jsonsecret-test  Test access to kubectl and gcloud                                        
workloadid-test  Test access to kubectl and gcloud                                        

ksa-can-i        Test KSA permissions using kubectl can-i                                 

teardown         remove deployments, KSA, and KSA/GSA binding                             

Which action (q to quit) ? 
```

## Expected test results

### generic-test

Container running as default service account. 

Will not be able to run kubectl nor gcloud commands.

### simpleksa-test

Container running as simple KSA 'my-ksa' that has permissions to pods and replicasets, but not daemonsets. 

Can run kubectl commands, but not gcloud commands.

### annotatedksa-test

Container running as KSA 'my-ksa-annotated' that has permissions to pods and daemonsetes, but not replicasets.  

Can run kubectl commands, but not gcloud commands.

The fact that the KSA is annotated with the GSA means that 'gcloud auth list' shows the GSA gcloud-user${project_id}.iam.gserviceaccount.com, but cannot assume its identity.

### jsonsecret-test

Container run as default service account.  

Will not be able to run kubectl commands, but can run gcloud commands because of mounted GSA secret, pointed to by environment variable CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE.

### workloadid-test

Container running as KSA 'my-wi-ksa', that has permission to daemonsets and replicasets, but not deployments.

Can run kubectl commands with RBAC role permissions provided by 'my-wi-ksa'.

Can run gcloud commands as 'gcloud-user@${project_id}.iam.gserviceaccount.com' GSA because of workload identity:
* 'iam.gke.io/gcp-service-account' annotation on KSA points to GSA 'gcloud-user'
* KSA to GSA binding command - gcloud iam service-accounts add-iam-policy-binding <GSA> -role roles/iam.workloadIdentityUser --member serviceAccount:${project_id}.svc.id.goog[<namespace>/my-wi-ksa]

## KSA RBAC Roles

KSA | Used in | pods | deployments | daemonsets | replicasets
---|---|---|---|---|---
my-ksa | kubectl-with-simple-ksa | yes | yes | no | yes
my-ksa-annotated | kubectl-with-annotated-ksa | yes | yes | yes | no
my-wi-ksa | workload-identity | yes | no | yes | yes

