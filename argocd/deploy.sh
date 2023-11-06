#!/usr/bin/env bash

set -e
set -o pipefail # Only exit with zero if all commands of the pipeline exit successfully

SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

NAMESPACE="argocd"
ARGOCD_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

echo "🚀 Creating namespace ${NAMESPACE}"
kubectl apply -f "${SCRIPT_DIR}/namespace.yaml"

echo "🚀 Deploying ArgoCD Prerequisites"
kubectl -n argocd apply -f "${ARGOCD_URL}"

