# linode-kubernetes/envoy-gateway

[Envoy Gateway](https://gateway.envoyproxy.io) is the cluster's Gateway API
implementation. It replaces Contour. The controller and CRDs are installed by
the Applications in [`argocd/envoy-gateway.yaml`](../argocd/envoy-gateway.yaml).

| File                | Contents                                                                    |
|---------------------|-----------------------------------------------------------------------------|
| `gatewayclass.yaml` | `envoy-gateway` GatewayClass, parameterized by the `public` EnvoyProxy      |
| `envoyproxy.yaml`   | Data plane: 2 Envoy replicas, Linkerd-injected, Service routing, Service type |
| `gateway.yaml`      | `public` Gateway and its listeners                                          |

Routes live with the applications they expose:

| Host                          | Route                                            | Backend                          |
|-------------------------------|--------------------------------------------------|----------------------------------|
| `argocd.ephemeral-roles.net`  | `argocd/httproute.yaml`                          | `argocd-server:80` (insecure mode) |
| `grafana.ephemeral-roles.net` | `monitoring/manifests/grafana-httproute.yaml`    | `grafana:3000`                   |
| `jaeger.ephemeral-roles.net`  | `observability/httproute.yaml`                   | `jaeger:16686`, behind basic auth |

A namespace must be listed in the Gateway's `allowedRoutes` selector before
its routes can attach.

The Envoy pods carry `linkerd.io/inject: enabled` and route to Service
cluster IPs (`routingType: Service`), so traffic from the Gateway to meshed
backends uses Linkerd mTLS. The public listener ports skip the Linkerd proxy,
so Envoy sees the real client IP.
