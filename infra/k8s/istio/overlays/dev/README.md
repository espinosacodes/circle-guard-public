# Istio development overlay

Apply the development-safe resilience policies with:

```bash
kubectl apply -f infra/k8s/istio/overlays/dev/
```

The production authorization policies are intentionally excluded. They depend
on production service accounts, JWT issuer configuration, and the
`circleguard-master` namespace.
