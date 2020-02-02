#!/usr/bin/env bash

set -e
set -o pipefail # Only exit with zero if all commands of the pipeline exit successfully

SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

setup() {
  pushd . > /dev/null 2>&1 && cd "${SCRIPT_DIR}"
}

build() {
  # Build kube-prometheus yaml files
  "${SCRIPT_DIR}/prometheus/build.sh"
}

deploy() {
  echo "🚀 Applying ephemeral-roles namespace yaml"
  kubectl apply -f "${SCRIPT_DIR}/ephemeral-roles/ephemeral-roles.yml"

  echo "🚀 Applying kube-prometheus setup manifest yamls"
  kubectl apply -f "${SCRIPT_DIR}/prometheus/manifests/setup"

  echo "🚀 Waiting for kube-prometheus setup to finish"
  until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done

  echo "🚀 Applying kube-prometheus manifest yamls"
  kubectl apply -f "${SCRIPT_DIR}/prometheus/manifests"

  echo "🚀 Applying ephemeral-roles servicemonitor yaml"
  kubectl apply -f "${SCRIPT_DIR}/prometheus/servicemonitor-ephemeral-roles.yaml"
}

cleanup() {
  popd > /dev/null 2>&1
}

trap cleanup EXIT

setup
build
deploy

echo "🚀 Deployment complete"
