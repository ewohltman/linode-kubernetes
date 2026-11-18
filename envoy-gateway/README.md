# linode-kubernetes/envoy-gateway

[Envoy Gateway](https://gateway.envoyproxy.io) is the cluster's Gateway API
implementation. It replaces Contour. The controller and CRDs are installed by
the Applications in [`argocd/envoy-gateway.yaml`](../argocd/envoy-gateway.yaml).

| File                | Contents                                                                    |
|---------------------|-----------------------------------------------------------------------------|
| `gatewayclass.yaml` | `envoy-gateway` GatewayClass, parameterized by the `public` EnvoyProxy      |
| `envoyproxy.yaml`   | Data plane: 2 Envoy replicas, Linkerd-injected, Service routing, LoadBalancer adopting the existing NodeBalancer |
| `gateway.yaml`      | `public` Gateway: `http` listener, one HTTPS listener per named host, and an `https-wildcard` listener, with Let's Encrypt certificates |
| `http-redirect.yaml`| Redirects HTTP to HTTPS for `*.ephemeral-roles.net` (ACME challenges still take precedence) |

Routes live with the applications they expose:

| Host                          | Route                                            | Backend                          |
|-------------------------------|--------------------------------------------------|----------------------------------|
| `argocd.ephemeral-roles.net`  | `argocd/httproute.yaml`                          | `argocd-server:80` (insecure mode) |
| `grafana.ephemeral-roles.net` | `monitoring/manifests/grafana-httproute.yaml`    | `grafana:3000`                   |
| `jaeger.ephemeral-roles.net`  | `observability/httproute.yaml`                   | `jaeger:16686`, behind basic auth |

To publish a new `<name>.ephemeral-roles.net` host, use the wildcard. A
`*.ephemeral-roles.net` DNS record already points at the Gateway, and the
wildcard certificate and HTTP redirect already cover the host.

1. Label the app's namespace:
   `kubectl label ns <namespace> ephemeral-roles.net/public-gateway=true`.
2. Add an HTTPRoute in that namespace with `sectionName: https-wildcard` and
   `hostnames: [<name>.ephemeral-roles.net]`.

The wildcard covers one label only: not the apex `ephemeral-roles.net` and
not `a.b.ephemeral-roles.net`. A host that needs its own certificate, or a
listener limited to a single namespace like argocd, grafana and jaeger, gets
a named listener instead:

1. Add a DNS A/AAAA record pointing at 45.79.61.251 / 2600:3c00:1::2d4f:3dfb.
2. Add an HTTPS listener for it to `gateway.yaml`, with its own
   `certificateRefs` Secret and an `allowedRoutes` selector for the app's
   namespace.
3. Add an HTTPRoute in the app's namespace with `sectionName` set to the
   new listener.

cert-manager issues the certificate within a minute or two.

The Envoy pods carry `linkerd.io/inject: enabled` and route to Service
cluster IPs (`routingType: Service`), so traffic from the Gateway to meshed
backends uses Linkerd mTLS. The public listener ports skip the Linkerd proxy,
so Envoy sees the real client IP.
