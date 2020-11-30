#!/usr/bin/env bash
set -e -u -o pipefail

source hack/commons.sh

info "Cluster upgrade : [$UPGRADE_CLUSTER]"

function install_openshift_pipelines_operator {
   CHANNEL="${1:-}"
   header "Installing Openshift pipelines operator Channel [$CHANNEL]"
   CHANNEL=$CHANNEL gauge run --env "default, test" --tags "install" --log-level=debug --verbose   $GOPATH/src/github.com/openshift-pipelines/release-tests/specs/olm.spec
}

function upgrade_openshift_pipelines_operator {
   CHANNEL="${1:-}"
   header "Upgrading Openshift pipelines operator to [$CHANNEL]"
   CHANNEL=$CHANNEL gauge run --env "default, test" --tags "upgrade" --log-level=debug --verbose   $GOPATH/src/github.com/openshift-pipelines/release-tests/specs/olm.spec
}

function uninstall_openshift_pipelines_operator {
   header "Uninstall Openshift pipelines operator"
   gauge run --env "default, test" --tags "uninstall" --log-level=debug --verbose   $GOPATH/src/github.com/openshift-pipelines/release-tests/specs/olm.spec
}

function run_rolling_upgrade_tests {
    header "Running rolling upgrade tests"

    local pipelines_in_scope triggers_in_scope
    scope="${1:?Provide an upgrade scope as arg[1]}"
    pipelines_in_scope="$(echo "${scope}" | grep -vq pipelines ; echo "$?")"
    triggers_in_scope="$(echo "${scope}" | grep -vq triggers ; echo "$?")"

    info "Ensure Openshift pipelines deployed and api's are ready to use"
    oc api-resources --api-group='tekton.dev' 2>/dev/null || {
         return $?
    }
    
    trap clean_test_namespaces ERR EXIT
    if (( pipelines_in_scope )); then
        $GOPATH/src/github.com/openshift-pipelines/pipelines-tutorial/demo.sh setup-pipeline || return $?

    fi
    if (( triggers_in_scope )); then
        $GOPATH/src/github.com/openshift-pipelines/pipelines-tutorial/demo.sh setup-triggers ||  return $?
    fi

    header "Running pre-upgrade tests"
    if (( pipelines_in_scope )); then
        $GOPATH/src/github.com/openshift-pipelines/pipelines-tutorial/demo.sh run || return $?
    fi
    
    if (( triggers_in_scope )); then
        run_triggers_tests || return $?
    fi
    
    if [[ $UPGRADE_CLUSTER == true ]]; then
        header "Upgrading Cluster...."
        upgrade_ocp_cluster ${UPGRADE_OCP_IMAGE:-} || return $?
    fi

    upgrade_openshift_pipelines_operator $CURRENT_VERSION || return $?

    info "Ensure Openshift pipelines deployed and api's are ready to use"
    oc api-resources --api-group='tekton.dev' 2>/dev/null || {
         return $?
    }

    header 'Running post-upgrade tests'
    if (( pipelines_in_scope )); then
        $GOPATH/src/github.com/openshift-pipelines/pipelines-tutorial/demo.sh run || return $?
    fi
    
    if (( triggers_in_scope )); then
        run_triggers_tests || return $?
    fi
}

run_rolling_upgrade_tests "${UPGRADE_TEST_SCOPE:-pipelines,triggers}" || failed=1
  
(( failed )) && fail_test
success