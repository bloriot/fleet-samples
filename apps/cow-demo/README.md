# Cow Demo

Source: [devpro/helm-charts](https://github.com/devpro/helm-charts/blob/main/charts/cow-demo/README.md)

## How to retrieve the values

Update `fleet.yaml` from the results of the following lines:

- Helm chart version

```bash
# adds helm chart repository
helm repo add devpro https://devpro.github.io/helm-charts
helm repo update

# searches for the latest version
helm search repo cow-demo
```

- Public IP

```bash
kubectl get service -n ingress-nginx ingress-nginx-controller --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
```
