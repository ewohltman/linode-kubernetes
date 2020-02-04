#!/usr/bin/env bash

set -e
set -o pipefail # Only exit with zero if all commands of the pipeline exit successfully

SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

echo "🚀 Applying kube-prometheus setup manifest yamls"
kubectl apply -f "${SCRIPT_DIR}/manifests/setup"

echo "🚀 Waiting for kube-prometheus setup to finish"
until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done

echo "🚀 Applying kube-prometheus manifest yamls"
kubectl apply -f "${SCRIPT_DIR}/manifests"

echo "🚀 Applying ephemeral-roles servicemonitor yaml"
kubectl apply -f "${SCRIPT_DIR}/servicemonitor-ephemeral-roles.yaml"
