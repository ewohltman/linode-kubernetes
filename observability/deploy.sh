#!/usr/bin/env bash

set -e
set -o pipefail # Only exit with zero if all commands of the pipeline exit successfully

SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

NAMESPACE="observability"
CERT_MANAGER_URL="https://github.com/cert-manager/cert-manager/releases/download/v1.6.3/cert-manager.yaml"
JAEGER_OPERATOR_URL="https://github.com/jaegertracing/jaeger-operator/releases/download/v1.37.0/jaeger-operator.yaml"

echo "🚀 Creating namespace ${NAMESPACE}"
kubectl apply -f "${SCRIPT_DIR}/namespace.yaml"

echo "🚀 Deploying Jaeger Prerequisites"
kubectl apply -f "${CERT_MANAGER_URL=}"

echo "🚀 Deploying Jaeger-Operator"
kubectl -n "${NAMESPACE}" apply -f "${JAEGER_OPERATOR_URL}"
kubectl -n "${NAMESPACE}" rollout status --timeout=60s deployment/jaeger-operator

echo "🚀 Deploying Jaeger"
kubectl -n "${NAMESPACE}" apply -f "${SCRIPT_DIR}/jaeger.yaml"
kubectl -n "${NAMESPACE}" apply -f "${SCRIPT_DIR}/service.yaml"
kubectl -n "${NAMESPACE}" apply -f "${SCRIPT_DIR}/httpproxy.yaml"

