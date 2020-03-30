#!/bin/sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

if [ -z $CI ]; then 
  echo "--- creating config map redhat-ca-config-map ---"
  oc create configmap redhat-ca-config-map --from-file=ca.crt=$DIR/RH-IT-Root-CA.crt -n openshift-config
else
  echo "--- creating secret htpass-secret ---"
  oc create secret generic htpass-secret --from-file=htpasswd=$DIR/users.htpasswd -n openshift-config
fi
