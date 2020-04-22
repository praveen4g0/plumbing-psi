#!/bin/sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

echo "Creating secret htpass-secret ---"
oc create secret generic htpass-secret --from-file=htpasswd=$DIR/users.htpasswd -n openshift-config

echo "Creating a htpasswd identity provider"
oc apply -f $DIR/test-oauth.yaml

echo "Creating cluster role bindings"
oc create clusterrolebinding pipelinesdeveloper_basic_user --clusterrole=basic-user --user=pipelinesdeveloper
oc create clusterrolebinding pipelinesdeveloper_view --clusterrole=view --user=pipelinesdeveloper

echo -e "Use one of the following users to login:\n"
echo "Username           | Password    | Cluster roles "
echo "-------------------|-----------------------------------------"
echo "user               | user        | default                   "
echo "user1              | user1       | default                   "
echo "...                | ...         | ...                       "
echo "user9              | user9       | default                   "
echo "pipelinesdeveloper | developer   | basic-user, view          "
echo "-------------------------------------------------------------"

