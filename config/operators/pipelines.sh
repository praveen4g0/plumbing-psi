#!/bin/bash

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-pipelines-operator
  namespace: openshift-operators
spec:
  channel: ocp-4.4
  name: openshift-pipelines-operator-rh
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

for i in {1..150}; do  # timeout after 5 minutes
  pods="$(oc get pods -n openshift-operators --no-headers 2>/dev/null | wc -l)"
  if [[ "${pods}" -eq 1 ]]; then
    echo -e "\nWaiting for Pipelines operator pod"
    oc wait --for=condition=Ready -n openshift-operators -l name=openshift-pipelines-operator pod --timeout=5m
    retval=$?
    if [[ "${retval}" -gt 0 ]]; then exit "${retval}"; else break; fi
  fi
  if [[ "${i}" -eq 150 ]]; then
    echo "Timeout: pod was not created."
    exit 2
  fi  
  echo -n "."
  sleep 2
done

for i in {1..150}; do  # timeout after 5 minutes
  pods="$(oc get pods -n openshift-pipelines --no-headers 2>/dev/null | wc -l)"
  if [[ "${pods}" -eq 4 ]]; then
    echo -e "\nWaiting for Pipelines and Triggers pods"
    oc wait --for=condition=Ready -n openshift-pipelines pod --timeout=5m \
      -l 'app in (tekton-pipelines-controller,tekton-pipelines-webhook,tekton-triggers-controller,
      tekton-triggers-webhook)'
    retval=$?
    if [[ "${retval}" -gt 0 ]]; then exit "${retval}"; else break; fi
  fi
  if [[ "${i}" -eq 150 ]]; then
    echo "Timeout: pod was not created."
    exit 2
  fi  
  echo -n "."
  sleep 2
done
