# linode-kubernetes/linkerd

[Linkerd](https://linkerd.io) (edge channel) is installed from the Helm
charts by the Applications in [`argocd/linkerd.yaml`](../argocd/linkerd.yaml).
This directory holds what the charts expect to exist already:

| File                 | Contents                                                              |
|----------------------|-----------------------------------------------------------------------|
| `namespaces.yaml`    | `linkerd` and `linkerd-viz` namespaces with the labels Linkerd uses     |
| `identity.yaml`      | Trust anchor (10y, key never rotated), identity issuer (48h, rotated daily) and the trust-manager Bundle that publishes `linkerd-identity-trust-roots` |
| `webhook-certs.yaml` | Webhook CA and serving certificates for the proxy injector, validators and viz tap |

All certificates are issued and renewed by cert-manager; nothing here
expires without being replaced automatically. The only long-term date to
remember is the trust anchor's renewal, about nine years after it's
created. Because its private key never rotates, the renewed root still
validates existing workload certificates.

Edge releases aren't versioned like stable releases: chart `2026.11.1` is
`edge-26.11.1`. Before upgrading, read the release notes at
<https://github.com/linkerd/linkerd2/releases> and check the Kubernetes
versions tested in `.github/workflows/integration.yml`.
