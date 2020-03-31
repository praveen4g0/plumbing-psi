#!/bin/sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

echo "Creating secret htpass-secret ---"
oc create secret generic htpass-secret --from-file=htpasswd=$DIR/users.htpasswd -n openshift-config

echo "Creating a htpasswd identity provider"
oc create -f test-oauth.yaml