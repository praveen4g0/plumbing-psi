#!/bin/bash

CLUSTER_NAME=$1
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
export OS_CLOUD=${OS_CLOUD:-"psi-pipelines"}

if [ -z $CLUSTER_NAME ]; then
  echo -e "Specify desired cluster name as a parameter of this script \n"
  echo "Usage:"
  echo "  $0 [name]"
  exit 1
fi

echo "Logging in to cluster $CLUSTER_NAME as kubeadmin"
export KUBECONFIG=$DIR/cluster/$CLUSTER_NAME/auth/kubeconfig
oc login -u kubeadmin -p $(cat $DIR/cluster/$CLUSTER_NAME/auth/kubeadmin-password)

echo "Configuring freshly provisioned OpenShift cluster"
if [ -z $CI ]; then
  # it's a long-running production cluster, the one running our CI/CD system
  oc new-project pipelines-ci

  $DIR/config/auth/01-prod-auth.sh
  $DIR/config/prune-images.sh
  $DIR/config/operators/cnv.sh
  $DIR/config/operators/container-security.sh
  $DIR/config/operators/pipelines.sh
  $DIR/config/secrets/secrets.sh
else
  # it's a temporary testing cluster
  $DIR/config/auth/01-test-auth.sh
fi
