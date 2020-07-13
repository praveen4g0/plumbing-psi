#!/bin/bash

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: container-security-operator
  namespace: openshift-operators
spec:
  channel: quay-v3.3
  name: container-security-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
