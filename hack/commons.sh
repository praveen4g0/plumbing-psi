#!/usr/bin/env bash
set -e -u -o pipefail

NAMESPACE=${NAMESPACE:-"pipelines-tutorial"}

failed=0
PREVIOUS_CHANNEL=${PREVIOUS_CHANNEL:-}
CURRENT_CHANNEL=${CURRENT_CHANNEL:-}
UPGRADE_OCP_IMAGE=${UPGRADE_OCP_IMAGE:-}
UPGRADE_CLUSTER=${UPGRADE_CLUSTER:-false}


_log() {
    local level=$1; shift
    echo -e "$level: $@"
}

log.err() {
    _log "ERROR" "$@" >&2
}

info() {
    _log "\nINFO" "$@"
}

err() {
    local code=$1; shift
    local msg="$@"; shift
    log.err $msg
    exit $code
}

print_err_without_exit() {
    local msg=$1; shift
    log.err $msg
}

if [ -z $CURRENT_CHANNEL ]; then
  echo -e "Specify desired operator current channel as a parameter of this script \n"
  echo "Usage:"
  echo "  $0 [channel]"
  exit 1
fi

if [[ $UPGRADE_CLUSTER == true ]]; then
  if [ -z $UPGRADE_OCP_IMAGE ]; then
    echo -e "Specify desired OCP image to upgrade cluster with as a parameter of this script \n"
    echo "Usage:"
    echo "  $0 [OCP_IMAGE]"
    exit 1
  fi
fi

function header() {
  local upper="$(echo $1 | tr a-z A-Z)"
  make_banner "=" "${upper}"
}

function make_banner() {
    local msg="$1$1$1$1 $2 $1$1$1$1"
    local border="${msg//[-0-9A-Za-z _.,\/()]/$1}"
    echo -e "${border}\n${msg}\n${border}"
}

function success() {
  echo "**************************************"
  echo "***      UPGRADE TESTS PASSED      ***"
  echo "**************************************"
  exit 0
}

function fail_test() {
  echo "***************************************"
  echo "***         E2E TEST FAILED         ***"
  echo "***    Start of information dump    ***"
  echo "***************************************"
  echo ">>> All resources:"
  oc get all --all-namespaces
  echo ">>> Services:"
  oc get services --all-namespaces
  echo ">>> Events:"
  oc get events --all-namespaces
  echo "***************************************"
  echo "***         E2E TEST FAILED         ***"
  echo "***     End of information dump     ***"
  echo "***************************************"
  exit 1
}

function clean_test_namespaces() {
  info "Ensure namespace $NAMESPACE exists"
  oc get ns "$NAMESPACE" 2>/dev/null  || {
    print_err_without_exit "Namespace $NAMESPACE doesn't exist" \
    && return 7
  }
  info "Cleaning test namespaces"
  oc delete project $NAMESPACE
  
  return 0
}

# Loops until duration (car) is exceeded or command (cdr) returns non-zero
function timeout {
  local timeout
  timeout="${1:?Pass a timeout as arg[1]}"
  interval="${interval:-1}"
  seconds=0
  shift
  ln=' ' info "${*} : Waiting until non-zero (max ${timeout} sec.)"
  while (eval "$*" 2>/dev/null); do
    seconds=$(( seconds + interval ))
    echo -n '.'
    sleep "$interval"
    [[ $seconds -gt $timeout ]] && echo '' \
      && print_err_without_exit "Time out of ${timeout} exceeded" \
      && return 71
  done
  [[ $seconds -gt 0 ]] && echo -n ' '
  echo 'done'
}

function upgrade_ocp_cluster {
  local upgrade_ocp_image latest_cluster_version
  upgrade_ocp_image="${1:-}"
  if [[ $UPGRADE_CLUSTER == true ]]; then
    if [[ -n "$upgrade_ocp_image" ]]; then
      oc adm upgrade --to-image="${UPGRADE_OCP_IMAGE}" \
        --force=true --allow-explicit-upgrade || return $?
      timeout 7400 "[[ \$(oc get clusterversion version -o jsonpath='{.status.history[?(@.image==\"${upgrade_ocp_image}\")].state}') != Completed ]]" || return $?
    else
      latest_cluster_version=$(oc adm upgrade | sed -ne '/VERSION/,$ p' \
        | grep -v VERSION | awk '{print $1}' | sort -r | head -n 1)
      [[ $latest_cluster_version != "" ]] || return 1
      oc adm upgrade --to-latest=true --force=true || return $?
      timeout 7400 "[[ \$(oc get clusterversion version -o=jsonpath='{.status.history[?(@.version==\"${latest_cluster_version}\")].state}') != Completed ]]" || return $?
    fi
  fi
  info "New cluster version: $(oc get clusterversion \
    version -o jsonpath='{.status.desired.version}')"
}


function run_triggers_tests {
  sleep 5

  APP_URL=$(oc get route vote-ui -n $NAMESPACE --template='http://{{.spec.host}}')
  info "Get Application URL: $APP_URL"

  info "Preview vote application state"
  lynx $APP_URL --dump || return $?

  info "\U0001F389 \U0001F389 Application is up! \U0001F389 \U0001F389"

  route=$(oc get route  -l eventlistener=vote-app -n $NAMESPACE -o name)
  url=$(oc get $route --template='http://{{.spec.host}}' -n $NAMESPACE)
  info "Eventlistener Route URL: $url"

  # Create and link secrets at runtime
  info "Create and link secerts to pipelines sa"
  oc create secret generic regcreds --from-literal=secretToken="1234567" -n $NAMESPACE 2>/dev/null || info "Secret Already exists"
  oc secret link serviceaccount/pipeline secrets/regcreds -n $NAMESPACE 2>/dev/null || info "Secret Already linked with SA"

  # Mock vote-api Github push event
  info "Mocking vote-api github push event"
  curl -X POST \
    ${url} \
  -H 'Content-Type: application/json' \
  -H 'X-Hub-Signature: sha1=648f5f80956fa5eb25e91391e91bba88556d05f3' \
  -d '{"head_commit": { "id": "master"},"repository":{"url": "https://github.com/openshift-pipelines/vote-api.git", "name": "vote-api"}}'

  sleep 5
  # Check for latest pipelinerun logs
  info "Check for latest pipelinerun logs"
  ./demo.sh logs

  # Mock vote-ui Github push event
  info "Mocking vote-ui github push event"
  curl -X POST \
    ${url} \
  -H 'Content-Type: application/json' \
  -H 'X-Hub-Signature: sha1=80c5be2df98752512b86a5fde7ad30981aaf6fc5' \
  -d '{"head_commit": { "id": "master"},"repository":{"url": "https://github.com/openshift-pipelines/vote-ui.git", "name": "vote-ui"}}'

  sleep 5
  # Check for latest pipelinerun logs
  info "Check for latest pipelinerun logs"
  ./demo.sh logs
  
  info "Validate pipelineruns"
  ./demo.sh validate_pipelinerun || return $?

  info "Preview vote application state"
  lynx $APP_URL --dump || return $?

  info "\U0001F389 \U0001F389 Application is up! \U0001F389 \U0001F389"
}