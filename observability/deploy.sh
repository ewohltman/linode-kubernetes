#!/usr/bin/env bash

set -e
set -o pipefail # Only exit with zero if all commands of the pipeline exit successfully

SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

NAMESPACE="observability"
JAEGER_OPERATOR_URL="https://github.com/jaegertracing/jaeger-operator/releases/download/v1.37.0/jaeger-operator.yaml"

echo "🚀 Creating namespace ${NAMESPACE}"
kubectl apply -f "${SCRIPT_DIR}/namespace.yaml"

# The Jaeger operator needs cert-manager, which ArgoCD now manages
# (argocd/cert-manager.yaml). Install that first.

echo "🚀 Deploying Jaeger-Operator"
kubectl -n "${NAMESPACE}" apply -f "${JAEGER_OPERATOR_URL}"
kubectl -n "${NAMESPACE}" rollout status --timeout=60s deployment/jaeger-operator

echo "🚀 Deploying Jaeger"
kubectl -n "${NAMESPACE}" apply -f "${SCRIPT_DIR}/jaeger.yaml"
kubectl -n "${NAMESPACE}" apply -f "${SCRIPT_DIR}/service.yaml"
kubectl -n "${NAMESPACE}" apply -f "${SCRIPT_DIR}/httpproxy.yaml"

