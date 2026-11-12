# linode-kubernetes
Configuration for Linode Kubernetes cluster

ArgoCD's `argocd` Application syncs the [`argocd/`](argocd) directory, so
every `Application` manifest in it is created and kept in sync
automatically (app-of-apps).

| Directory                          | Contents                                                              |
|------------------------------------|-----------------------------------------------------------------------|
| [`argocd/`](argocd)                | ArgoCD namespace, Applications, argocd-server route and parameters    |
| [`cert-manager/`](cert-manager)    | ClusterIssuers: self-signed bootstrap, Let's Encrypt staging and production |
| [`linkerd/`](linkerd)              | Linkerd namespaces, cert-manager identity CA and webhook certificates |
| [`envoy-gateway/`](envoy-gateway)  | GatewayClass, EnvoyProxy and the `public` Gateway (HTTPS, Let's Encrypt) |
| [`monitoring/`](monitoring)        | kube-prometheus (generated) and the Grafana route                     |
| [`observability/`](observability)  | Jaeger, its route and its basic-auth SecurityPolicy                   |

Public hosts, all HTTPS through the Envoy Gateway on 45.79.61.251:
`argocd`, `grafana` and `jaeger` under `ephemeral-roles.net`.

See [MIGRATION.md](MIGRATION.md) for how the cluster moved from Contour to
Envoy Gateway, cert-manager, Let's Encrypt and Linkerd.
