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

- **Remove the v1.6.3 conversion webhook from the cert-manager CRDs.** The
  old CRDs set `conversion.strategy: Webhook`, pointing at
  `cert-manager-webhook` `/convert`. The v1.21 CRDs have no conversion
  section. The old CRDs predate server-side apply and have no field
  owners, so ArgoCD can't remove the webhook block. The API server then
  rejects the merged CRD (`spec.conversion.strategy: Required value`), and
  the issuers lose their Gateway API fields. Every version is `v1` only,
  so nothing needs converting:

  ```sh
  for c in certificates.cert-manager.io certificaterequests.cert-manager.io \
           issuers.cert-manager.io clusterissuers.cert-manager.io \
           orders.acme.cert-manager.io challenges.acme.cert-manager.io; do
    kubectl patch crd "$c" --type=merge \
      -p '{"spec":{"conversion":{"strategy":"None","webhook":null}}}'
  done
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
- Jaeger gets a basic-auth SecurityPolicy. Until its Secret exists, Envoy
  Gateway answers that route with 500, so it fails closed.
- argocd-server switches to insecure mode (`server.insecure: "true"`),
  because TLS will end at the Gateway.
- Contour's Envoy Service gets `linode-loadbalancer-preserve: "true"`, so
  deleting it in phase 4 keeps the NodeBalancer and its IPs.

Before landing:

1. Create Jaeger's basic-auth users file as a Secret. It is never
   committed. Envoy Gateway only accepts the unsalted `{SHA}` htpasswd
   format, so use a long random password that isn't used anywhere else:

   ```sh
   PASS=$(openssl rand -base64 24)
   HASH=$(printf '%s' "$PASS" | openssl dgst -binary -sha1 | openssl base64)
   kubectl -n observability create secret generic jaeger-basic-auth \
     --from-literal=.htpasswd="jaeger:{SHA}$HASH"
   echo "jaeger / $PASS"    # keep this in a password manager
   ```

   The Secret can also be created later. Until then the Jaeger route
   returns 500.

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
curl -sI -H 'Host: jaeger.ephemeral-roles.net' localhost:8080/          # 401 (500 until the Secret exists)
curl -sI -u "jaeger:$PASS" -H 'Host: jaeger.ephemeral-roles.net' localhost:8080/   # 200
```

## Phase 4: cut over to Envoy Gateway, HTTPS everywhere, remove Contour

What changes:

- The Envoy Gateway Service becomes a LoadBalancer that **adopts Contour's
  NodeBalancer**, so the public IPs (45.79.61.251, 2600:3c00:1::2d4f:3dfb)
  and DNS stay the same. It's also marked `preserve`.
- The `public` Gateway gets one HTTPS listener per host. cert-manager
  issues a Let's Encrypt certificate for each through HTTP-01 on the `http`
  listener. Plain HTTP is redirected to HTTPS, apart from ACME challenges.
- Each HTTPS listener accepts routes only from its app's namespace. The
  app routes move from `http` to their `https-*` listener.
- Contour, every HTTPProxy, and the Prometheus Role/RoleBinding in
  `projectcontour` are removed.

Before landing:

1. Phase 3 is healthy and its port-forward tests pass. The `jaeger-oidc`
   Secret exists.
2. The NodeBalancer ID in `envoy-gateway/envoyproxy.yaml` is `250811`
   (the NodeBalancer with IP 45.79.61.251).
3. **Add the missing DNS records** in Linode DNS Manager:
   `argocd.ephemeral-roles.net` A `45.79.61.251` and AAAA
   `2600:3c00:1::2d4f:3dfb`. Without them, Let's Encrypt can't validate
   `argocd` (grafana and jaeger already resolve).
4. Confirm the NodeBalancer will survive Contour's removal:

   ```sh
   kubectl -n projectcontour get svc envoy \
     -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/linode-loadbalancer-preserve}'; echo   # true
   ```

Cutover (public HTTP is down for a few minutes between steps 5 and 6):

5. Remove Contour. The `projectcontour` Application isn't in this
   repository and has no cascade finalizer, so add one, then delete it.
   This deletes Contour, its Envoy pods and Service (the NodeBalancer is
   kept), the HTTPProxy CRDs and the `projectcontour` namespace.

   ```sh
   kubectl -n argocd patch application projectcontour --type merge \
     -p '{"metadata":{"finalizers":["resources-finalizer.argocd.argoproj.io"]}}'
   kubectl -n argocd delete application projectcontour
   kubectl get ns projectcontour     # wait until it's gone
   ```

6. Land the phase 4 commit and the commit after it, which sets the
   NodeBalancer ID.

After landing:

```sh
kubectl -n envoy-gateway-system get svc \
  -l gateway.envoyproxy.io/owning-gateway-name=public   # EXTERNAL-IP 45.79.61.251
kubectl -n envoy-gateway-system get certificate          # 3 certificates Ready within a few minutes
curl -sI http://grafana.ephemeral-roles.net/             # 301 to https://
curl -sI https://grafana.ephemeral-roles.net/login       # 200, valid Let's Encrypt certificate
curl -sI https://jaeger.ephemeral-roles.net/             # 302 to accounts.google.com
kubectl -n observability get securitypolicy jaeger-oidc  # Accepted
argocd login --grpc-web argocd.ephemeral-roles.net
```

If a certificate stays pending, check `kubectl -n envoy-gateway-system get
challenges` and `kubectl describe` them. The usual causes are missing DNS or
the NodeBalancer not having moved yet.

Rollback: revert this commit, then recreate Contour from phase 3 with
`git show <phase-3-commit>:projectcontour/contour.yaml | kubectl apply -f -`,
after adding `service.beta.kubernetes.io/linode-loadbalancer-nodebalancer-id`
to its `envoy` Service so it takes the NodeBalancer back.

## Afterwards

- Mesh the backends (`argocd-server`, `grafana`, `jaeger`) with
  `linkerd.io/inject: enabled`, so the hop from the Gateway to each backend
  uses mTLS. Then add Linkerd `AuthorizationPolicy` resources that admit
  only the Gateway's identity on those ports.
- Grafana has anonymous viewing enabled in `monitoring/config.jsonnet`
  (`auth.anonymous`). Keep it only if the dashboards are meant to be public.
- When cert-manager v1.22 is released (expected to add Kubernetes 1.37),
  bump `argocd/cert-manager.yaml`.
