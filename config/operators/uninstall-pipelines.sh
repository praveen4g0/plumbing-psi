#!/bin/bash

echo "Uninstalling OpenShift Pipelines operator"

# Delete instance (name: cluster) of config.operator.tekton.dev
oc delete config.operator.tekton.dev cluster --cascade=true

# Add some wait, before deleting the controller, as it could handle the event
sleep 30

# Delete ClusterServiceVersion (CSV)
oc delete $(oc get csv  -n openshift-operators -o name) -n openshift-operators  --cascade=true

# Delete InstallPlan
oc delete -n openshift-operators installplan $(oc get subscription openshift-pipelines-operator-rh -n openshift-operators -o jsonpath='{.status.installplan.name}')  --cascade=true

# Delete Pipelines operator subscription
oc delete subscription openshift-pipelines-operator-rh -n openshift-operators 