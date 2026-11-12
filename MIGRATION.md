# Migration: cert-manager, Let's Encrypt, Linkerd and Envoy Gateway

This branch has one commit per phase. Land them on `master` one at a time,
for example by fast-forwarding `master` to each commit in turn, and finish
each phase's checks before landing the next. The `argocd` Application syncs
the `argocd/` directory, so a new `Application` manifest there is created
automatically once it reaches `master`.

All commands assume `kubectl --context lke1275-ctx`.

## Phase 1: cert-manager v1.21 and Let's Encrypt issuers

What changes:

- cert-manager moves from the hand-applied v1.6.3 manifests to the Helm chart
  (v1.21.3), managed by ArgoCD, with Gateway API support enabled.
- trust-manager v0.26.0 is installed.
- ClusterIssuers `selfsigned`, `letsencrypt-staging` and `letsencrypt-prod`
  are added. The Let's Encrypt issuers aren't usable until the `public`
  Gateway exists (phase 3) and receives traffic (phase 4).

Before landing:

- The cert-manager CRDs already store only `v1`, so no API migration is
  needed (checked 2026-11-12).
- cert-manager v1.21 officially supports Kubernetes 1.33–1.36. If v1.22 has
  been released, bump `targetRevision` in `argocd/cert-manager.yaml`.
- **Delete the three v1.6.3 Deployments right before landing.** In v1.6.3
  every container is named `cert-manager`, but the chart names them
  `cert-manager-controller`, `-cainjector` and `-webhook`. Server-side apply
  merges containers by name, so applying over the old Deployments would keep
  the old container next to the new one, and both would fight for the same
  port. Every other object applies cleanly over the old install (checked
  with a server-side dry run). Issued certificates and their Secrets aren't
  affected; cert-manager is only absent until ArgoCD recreates it.

  ```sh
  kubectl -n cert-manager delete deploy cert-manager cert-manager-cainjector cert-manager-webhook
  ```

After landing:

```sh
kubectl -n cert-manager get deploy -o wide        # images at v1.21.3
kubectl get clusterissuers                        # all three Ready=True
kubectl -n observability get certificate          # jaeger-operator cert still Ready
kubectl get mutatingwebhookconfiguration jaeger-operator-mutating-webhook-configuration \
  -o jsonpath='{.webhooks[0].clientConfig.caBundle}' | head -c 40; echo   # still injected
```

## Phase 2: Linkerd through ArgoCD, with cert-manager-issued identity

What changes:

- Linkerd edge-26.11.1 (`linkerd-crds`, `linkerd-control-plane`,
  `linkerd-viz`) is installed from the Helm charts, managed by ArgoCD.
- The trust anchor is a cert-manager private CA (10 years, key never
  rotated). The identity issuer is a 48h intermediate that cert-manager
  rotates daily. trust-manager publishes the anchor as
  `linkerd-identity-trust-roots`. This removes the 2027-11-12 expiry of
  the CLI-generated certificates.
- Webhook and tap serving certificates come from cert-manager, and
  cainjector fills in their `caBundle`. With the charts' generated
  certificates, every ArgoCD render would produce new random ones.
- The heartbeat CronJob is disabled, and viz's bundled Prometheus gets a
  512Mi memory limit.

Before landing (phase 1 must be healthy):

The CLI install generated a trust anchor whose private key wasn't kept, so
cert-manager can't adopt it. Nothing outside `linkerd` and `linkerd-viz` is
meshed yet, so uninstall and reinstall instead of rotating. Viz has to go
first, or `linkerd uninstall` prints nothing. Neither command touches the
Gateway API CRDs.

```sh
linkerd viz uninstall | kubectl delete -f -
linkerd uninstall | kubectl delete -f -
kubectl get ns linkerd linkerd-viz     # wait until both are gone
```

After landing:

```sh
kubectl -n linkerd get certificate               # identity + webhook certs Ready
kubectl -n linkerd get cm linkerd-identity-trust-roots
linkerd check
linkerd viz check
```

If any namespaces were meshed in the meantime, restart their workloads so
the proxies get certificates from the new trust anchor.

## Phase 3: Envoy Gateway beside Contour (no public traffic yet)

What changes:

- Gateway API CRDs move to v1.6.1 (standard channel), owned by Envoy
  Gateway's `gateway-crds-helm` chart. The v1.3.0 CRDs Istio left behind are
  adopted in place; every stored version is still served (dry-run checked).
- Envoy Gateway v1.10.0 is installed. The `public` Gateway runs 2 Envoy
  replicas behind a **ClusterIP** Service, with Linkerd injected and
  `routingType: Service`.
- HTTPRoutes for argocd, grafana and jaeger attach to the Gateway's `http`
  listener, beside the existing HTTPProxies.
- Jaeger gets a Google OIDC SecurityPolicy. Until its Secret exists, Envoy
  Gateway answers that route with 500, so it fails closed.
- argocd-server switches to insecure mode (`server.insecure: "true"`),
  because TLS will end at the Gateway.
- Contour's Envoy Service gets `linode-loadbalancer-preserve: "true"`, so
  deleting it in phase 4 keeps the NodeBalancer and its IPs.

Before landing:

1. Create the Google OAuth client for Jaeger:
   - Google Cloud console → APIs & Services → OAuth consent screen: user
     type *External*, publishing status *Testing*, and add each account
     allowed to sign in as a *test user*. Only test users can sign in while
     the app is in Testing.
   - Credentials → Create OAuth client ID → *Web application*, with the
     authorized redirect URI `https://jaeger.ephemeral-roles.net/oauth2/callback`.
2. Store it in the cluster. It is never committed:

   ```sh
   kubectl -n observability create secret generic jaeger-oidc \
     --from-literal=client-id=<id>.apps.googleusercontent.com \
     --from-literal=client-secret=<secret>
   ```

After landing:

```sh
kubectl -n projectcontour get svc envoy \
  -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/linode-loadbalancer-preserve}'; echo   # must print true
kubectl -n argocd rollout restart deploy argocd-server         # pick up server.insecure
kubectl get gatewayclass envoy-gateway                         # Accepted=True
kubectl -n envoy-gateway-system get gateway public             # Programmed=True
kubectl get httproute -A                                       # argocd-server, grafana, jaeger Accepted
linkerd viz stat deploy -n envoy-gateway-system                # Envoy pods meshed
```

The `observability` Application isn't in this repository and has no sync
retry. If it synced before the SecurityPolicy CRD existed, it stays
`SyncFailed` for this commit. Re-sync it once `gateway-api-crds` is healthy:

```sh
kubectl -n argocd patch application observability --type merge -p '{"operation":{"sync":{}}}'
```

Test the Gateway from inside the cluster before cutting over:

```sh
SVC=$(kubectl -n envoy-gateway-system get svc -o name \
  -l gateway.envoyproxy.io/owning-gateway-name=public)
kubectl -n envoy-gateway-system port-forward "$SVC" 8080:80 &
curl -sI -H 'Host: grafana.ephemeral-roles.net' localhost:8080/login   # 200
curl -sI -H 'Host: argocd.ephemeral-roles.net' localhost:8080/          # 200
curl -sI -H 'Host: jaeger.ephemeral-roles.net' localhost:8080/          # 302 to accounts.google.com
```
