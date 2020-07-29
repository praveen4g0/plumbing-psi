#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

echo "Configure secrets"

if [ ! -f "$DIR/secrets.env" ]; then
  echo "You have to provide file $DIR/secrets.env! You can use the template $DIR/secrets.env-template"
  exit 1
fi

if [ ! -f "$DIR/pull-secret" ]; then
  echo "You have to provide file $DIR/pull-secret! You can download it from https://www.openshift.com/try"
  exit 2
fi

source "$DIR/secrets.env"

echo -e "\nConfiguring AWS credentials"
sed -e "s/\$AWS_ACCESS_KEY_ID/$AWS_ACCESS_KEY_ID/" \
    -e "s/\$AWS_SECRET_ACCESS_KEY/$AWS_SECRET_ACCESS_KEY/" \
    "$DIR/../../ci/secrets/aws.yaml" | oc apply -f -

if [[ "$OSTYPE" == "darwin"* ]]; then
  ENCODE_BASE64="base64"
else
  ENCODE_BASE64="base64 -w 0"
fi
ENCODED_PULL_SECRET=$(cat $DIR/pull-secret | $ENCODE_BASE64)

echo -e "\nConfiguring OpenShift installer secrets"
sed -e "s/\$PULL_SECRET/$ENCODED_PULL_SECRET/" \
    -e "s/\$UPLOADER_USERNAME/$UPLOADER_USERNAME/" \
    -e "s/\$UPLOADER_PASSWORD/$UPLOADER_PASSWORD/" \
    "$DIR/../../ci/secrets/openshift-install.yaml" | oc apply -f -

echo -e "\nConfiguring PSI cloud credentials"
sed -e "s/\$PSI_CLOUD_USERNAME/$PSI_CLOUD_USERNAME/" \
    -e "s/\$PSI_CLOUD_PASSWORD/$PSI_CLOUD_PASSWORD/" \
    "$DIR/../../ci/secrets/psi.yaml" | oc apply -f -
