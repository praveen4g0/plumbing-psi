#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

echo "Configure secrets"

if [ ! -f "$DIR/secrets.env" ]; then
  echo "You have to provide file $DIR/secrets.env! You can use the template $DIR/secrets.env-template."
  exit 1
fi

if [ ! -f "$DIR/pull-secret" ]; then
  echo "You have to provide file $DIR/pull-secret! You can download it from https://www.openshift.com/try."
  exit 2
fi

if [ ! -f "$DIR/psi-pipelines-shared.pem" ]; then
  echo "You have to provide file $DIR/psi-pipelines-shared.pem! Ask any QE team member to share it with you."
  exit 2
fi

source "$DIR/secrets.env"

if [[ "$OSTYPE" == "darwin"* ]]; then
  ENCODE_BASE64="base64"
else
  ENCODE_BASE64="base64 -w 0"
fi

ENCODED_PULL_SECRET=$(cat $DIR/pull-secret | $ENCODE_BASE64)
ENCODED_SSH_PRIVATE_KEY=$(cat $DIR/psi-pipelines-shared.pem | $ENCODE_BASE64)
QUAY_IO_USERNAME=$(cat $DIR/pull-secret | jq -r '.auths["quay.io"].auth' | base64 -d | cut -d":" -f1)
QUAY_IO_PASSWORD=$(cat $DIR/pull-secret | jq -r '.auths["quay.io"].auth' | base64 -d | cut -d":" -f2)
REGISTRY_RH_IO_USERNAME=$(cat $DIR/pull-secret | jq -r '.auths["registry.redhat.io"].auth' | base64 -d | cut -d":" -f1)
REGISTRY_RH_IO_PASSWORD=$(cat $DIR/pull-secret | jq -r '.auths["registry.redhat.io"].auth' | base64 -d | cut -d":" -f2)

echo -e "\nConfiguring AWS credentials"
sed -e "s/\$AWS_ACCESS_KEY_ID/$AWS_ACCESS_KEY_ID/" \
    -e "s/\$AWS_SECRET_ACCESS_KEY/$AWS_SECRET_ACCESS_KEY/" \
    "$DIR/../../ci/secrets/aws.yaml" | oc apply -f -

echo -e "\nConfiguring OpenShift installer secrets"
sed -e "s/\$PULL_SECRET/$ENCODED_PULL_SECRET/" \
    -e "s/\$UPLOADER_USERNAME/$USERNAME/" \
    -e "s/\$UPLOADER_PASSWORD/$PASSWORD/" \
    "$DIR/../../ci/secrets/openshift-install.yaml" | oc apply -f -

echo -e "\nConfiguring PSI cloud credentials"
sed -e "s/\$PSI_CLOUD_USERNAME/$PSI_CLOUD_USERNAME/g" \
    -e "s/\$PSI_CLOUD_PASSWORD/$PSI_CLOUD_PASSWORD/g" \
    "$DIR/../../ci/secrets/psi.yaml" | oc apply -f -

echo -e "\nConfiguring p12n secrets"
sed -e "s/\$STAGE_USER/$USERNAME/" \
    -e "s/\$STAGE_PASSWORD/$PASSWORD/" \
    -e "s/\$PRE_STAGE_TOKEN/$PRE_STAGE_TOKEN/" \
    -e "s/\$STAGE_TOKEN/$STAGE_TOKEN/" \
    "$DIR/../../ci/secrets/p12n.yaml" | oc apply -f -

echo -e "\nConfiguring Flexy secrets"
sed -e "s/\$AWS_ACCESS_KEY_ID/$AWS_ACCESS_KEY_ID/" \
    -e "s/\$AWS_SECRET_ACCESS_KEY/$AWS_SECRET_ACCESS_KEY/" \
    -e "s/\$DYNDNS_USERNAME/$DYNDNS_USERNAME/g" \
    -e "s/\$DYNDNS_PASSWORD/$DYNDNS_PASSWORD/g" \
    -e "s/\$PSI_CLOUD_USERNAME/$PSI_CLOUD_USERNAME/g" \
    -e "s/\$PSI_CLOUD_PASSWORD/$PSI_CLOUD_PASSWORD/g" \
    -e "s/\$QUAY_IO_USERNAME/$QUAY_IO_USERNAME/g" \
    -e "s/\$QUAY_IO_PASSWORD/$QUAY_IO_PASSWORD/g" \
    -e "s/\$REGISTRY_RH_IO_USERNAME/$REGISTRY_RH_IO_USERNAME/g" \
    -e "s/\$REGISTRY_RH_IO_PASSWORD/$REGISTRY_RH_IO_PASSWORD/g" \
    -e "s/\$SSH_PRIVATE_KEY/$ENCODED_SSH_PRIVATE_KEY/g" \
    "$DIR/../../ci/secrets/flexy.yaml" | oc apply -f -
