#!/bin/sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

KUBEADMIN_PASS=$(oc get secret -n openshift-config htpass-secret -o jsonpath={.data.htpasswd} 2> /dev/null | base64 -d | grep kubeadmin)
if [ $? == 0 ]; then
  echo "Kubeadmin password found in secret called 'htpass-secret'. This is expected on CRC clusters."
  HTPASSWD_FILE=$(mktemp /tmp/htpasswd.XXX)
  echo $KUBEADMIN_PASS >> "$HTPASSWD_FILE"
  cat $DIR/users.htpasswd >> "$HTPASSWD_FILE"

  echo "Updating secret htpass-secret"
  PATCH="{\"data\":{\"htpasswd\":\"$(cat $HTPASSWD_FILE | base64 -w 0)\"}}"
  oc patch secret htpass-secret -n openshift-config -p=$PATCH -v=1
  rm "$HTPASSWD_FILE"
else
  echo "Creating secret htpass-secret"
  oc create secret generic htpass-secret --from-file=htpasswd="$DIR/users.htpasswd" -n openshift-config
fi

echo "Creating a htpasswd identity provider"
oc apply -f $DIR/test-oauth.yaml

echo "Creating cluster role bindings"
oc create clusterrolebinding pipelinesdeveloper_basic_user --clusterrole=basic-user --user=pipelinesdeveloper

oc create clusterrolebinding consoledeveloper_self_provisioner --clusterrole=self-provisioner --user=consoledeveloper
oc create clusterrolebinding consoledeveloper_view --clusterrole=view --user=consoledeveloper

echo -e "Use one of the following users to login:\n"
echo "Username           | Password    | Cluster roles "
echo "-------------------|-----------------------------------------"
echo "consoledeveloper   | developer   | self-provisioner, view    "
echo "pipelinesdeveloper | developer   | basic-user                "
echo "user               | user        | default                   "
echo "user1              | user1       | default                   "
echo "...                | ...         | ...                       "
echo "user9              | user9       | default                   "
echo "-------------------------------------------------------------"

