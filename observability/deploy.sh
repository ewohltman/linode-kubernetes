#!/usr/bin/env bash

kubectl apply -f namespace.yaml

kubectl -n observability apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/crds/jaegertracing.io_jaegers_crd.yaml
kubectl -n observability apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/service_account.yaml
kubectl -n observability apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/role.yaml
kubectl -n observability apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/role_binding.yaml

kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/cluster_role.yaml
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/cluster_role_binding.yaml

kubectl -n observability apply -f jaeger-operator.yaml
kubectl -n observability rollout status --timeout=60s deployment/jaeger-operator

kubectl -n observability apply -f jaeger.yaml

kubectl -n observability apply -f jaeger-service.yaml

kubectl -n observability apply -f jaeger-httpproxy.yaml