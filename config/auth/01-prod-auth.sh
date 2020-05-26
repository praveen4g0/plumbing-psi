#!/bin/sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

echo "Creating config map redhat-ca-config-map"
oc create configmap redhat-ca-config-map --from-file=ca.crt=$DIR/RH-IT-Root-CA.crt -n openshift-config

echo "Creating an LDAP identity provider"
oc apply -f $DIR/prod-oauth.yaml

echo "Syncing LDAP groups to the cluster"
oc adm groups sync --sync-config=$DIR/prod-ldap-sync.yaml --confirm

echo "Adding cluster-admin role to the group tekton-team"
oc adm policy add-cluster-role-to-group cluster-admin tekton-team

echo "Deleting kubeadmin acccount"
oc delete secrets kubeadmin -n kube-system

