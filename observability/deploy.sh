#!/usr/bin/env bash

set -e
set -o pipefail # Only exit with zero if all commands of the pipeline exit successfully

SCRIPT_PATH=$(readlink -f "${0}")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")

NAMESPACE="observability"
JAEGER_DEPLOY_URL="https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy"

echo "🚀 Creating namespace ${NAMESPACE}"
kubectl apply -f "${SCRIPT_DIR}/namespace.yaml"

echo "🚀 Deploying Jaeger configuration"
kubectl -n "${NAMESPACE}" apply -f "${JAEGER_DEPLOY_URL}/crds/jaegertracing.io_jaegers_crd.yaml"
kubectl -n "${NAMESPACE}" apply -f "${JAEGER_DEPLOY_URL}/service_account.yaml"
kubectl -n "${NAMESPACE}" apply -f "${JAEGER_DEPLOY_URL}/role.yaml"
kubectl -n "${NAMESPACE}" apply -f "${JAEGER_DEPLOY_URL}/role_binding.yaml"

kubectl apply -f "${JAEGER_DEPLOY_URL}/cluster_role.yaml"
kubectl apply -f "${JAEGER_DEPLOY_URL}/cluster_role_binding.yaml"

echo "🚀 Deploying Jaeger-Operator"
kubectl -n "${NAMESPACE}" apply -f "${SCRIPT_DIR}/jaeger-operator.yaml"
kubectl -n "${NAMESPACE}" rollout status --timeout=60s deployment/jaeger-operator
