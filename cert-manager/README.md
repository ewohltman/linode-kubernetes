# linode-kubernetes/cert-manager

Issuers for [cert-manager](https://cert-manager.io). cert-manager and
[trust-manager](https://cert-manager.io/docs/trust/trust-manager/) are
installed from their Helm charts by the Applications in
[`argocd/cert-manager.yaml`](../argocd/cert-manager.yaml).

| ClusterIssuer         | Purpose                                                           |
|-----------------------|-------------------------------------------------------------------|
| `selfsigned`          | Bootstraps private CAs (Linkerd trust anchor, Linkerd webhook CA) |
| `letsencrypt-staging` | Let's Encrypt staging; for testing, not browser-trusted           |
| `letsencrypt-prod`    | Let's Encrypt production; public HTTPS on the Envoy Gateway       |

The Let's Encrypt issuers solve HTTP-01 challenges with a Gateway API
HTTPRoute attached to the `http` listener of the `public` Gateway in
`envoy-gateway-system`. No ACME account email is configured, because Let's
Encrypt no longer sends expiry emails.
