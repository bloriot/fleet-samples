# Cluster RKE2 sur Harvester via Fleet (GitOps)

Ce dossier vit dans `bloriot/fleet-samples`. Les chemins ci-dessous sont relatifs à `rke2-harvester/`.

Ce dépôt déploie un cluster RKE2 sur Harvester avec le node driver Harvester de Rancher, piloté par Fleet.
Il est prévu pour Rancher v2.15.x avec un cluster Harvester déjà importé.

## Principe

Fleet applique, sur le cluster `local` de Rancher, un chart Helm qui crée dans `fleet-default` :

- un `provisioning.cattle.io/v1 Cluster` (RKE2) ;
- un `HarvesterConfig` (`rke-machine-config.cattle.io/v1`) par pool de machines.

Rancher provisionne ensuite les VMs sur Harvester.

```
Git ──> Fleet (fleet-local) ──> chart Helm ──> Cluster + HarvesterConfig (fleet-default)
                                                    └─> Rancher ──> VMs Harvester ──> RKE2
```

Deux secrets contiennent des identifiants et ne doivent **pas** être dans Git :

| Secret | Namespace | Rôle |
| --- | --- | --- |
| Cloud credential Harvester | `cattle-global-data` | Permet à Rancher de créer les VMs |
| Kubeconfig du cloud provider | `fleet-default` | Permet au CCM/CSI Harvester du cluster invité de parler à Harvester |

Rancher ne crée le second automatiquement que depuis l'UI. Lors d'un provisioning par API ou GitOps, il faut le créer soi-même. Voir [rancher/rancher#54417](https://github.com/rancher/rancher/issues/54417).

## Arborescence

```
charts/harvester-rke2-cluster/   chart Helm (bundle Fleet)
  fleet.yaml                     options Fleet (namespace cible, release Helm)
  values.yaml                    paramètres du cluster et des pools
fleet/gitrepo.yaml               GitRepo à appliquer une fois sur Rancher
scripts/harvester-secrets.sh     création des deux secrets hors Git
```

## Mise en route

### 1. Prérequis côté Harvester

- Une `VMImage` cloud (Ubuntu 22.04/24.04 par exemple) dans Harvester.
- Un VM network pour les VMs.
- Renseignez `imageName` et `networkName` (format `<namespace>/<nom>`) dans `machineDefaults` de `values.yaml`.
- Vérifiez `cluster.kubernetesVersion`. Les versions disponibles sont listées par `curl -sk https://<rancher>/v1-rke2/releases`.

### 2. Créer le secret du cloud provider (seulement avec `cloudProvider: harvester`)

Par défaut (`cloudProvider: ""`), le cluster utilise "Default - RKE2 Embedded" et cette étape est inutile. Passez à l'étape 3.

Avec `kubectl` pointant sur le cluster local de Rancher (`jq` et `curl` requis) :

```bash
export RANCHER_URL=https://rancher.example.com
export RANCHER_TOKEN=token-xxxxx:yyyyyyyy      # token API Rancher
export HARVESTER_CLUSTER_NAME=harvester        # nom du cluster Harvester importé
export CLUSTER_NAME=rke2-harvester-test        # = cluster.name dans values.yaml
export VM_NAMESPACE=default                    # = machineDefaults.vmNamespace

./scripts/harvester-secrets.sh cloudprovider
```

Le cloud credential est celui créé depuis l'UI (`cc-58bb7`, déjà reporté dans `cloudCredentialSecretName`). Sans credential existant, `./scripts/harvester-secrets.sh all` en crée un.

> Le nom du ServiceAccount créé côté Harvester et l'annotation `v2prov-secret-authorized-for-cluster` doivent être égaux au nom du cluster. Le secret ne peut pas être partagé entre plusieurs clusters.

### 3. Créer le GitRepo

Le dépôt `bloriot/fleet-samples` est public, donc Fleet le lit sans secret. Le chart est dans le sous-dossier `rke2-harvester/`.

```bash
kubectl apply -f fleet/gitrepo.yaml
```

### 4. Suivre le déploiement

```bash
kubectl get gitrepo -n fleet-local
kubectl get bundle -n fleet-local
kubectl get clusters.provisioning.cattle.io -n fleet-default
kubectl get machines.cluster.x-k8s.io -n fleet-default
```

Dans l'UI : *Continuous Delivery > Git Repos* et *Cluster Management*.

## Valider le rendu en local

```bash
helm lint charts/harvester-rke2-cluster
helm template t charts/harvester-rke2-cluster
```

## Points d'attention

- **Suppression** : retirer le `GitRepo` ou le chart supprime le `Cluster`, donc les VMs.
- **Statut `Modified` dans Fleet** : Rancher modifie les objets après création. Si le bundle reste en `Modified`, ajoutez des `diff.comparePatches` dans `fleet.yaml` (exemple commenté).
- **Modification d'un pool** : les `HarvesterConfig` sont nommés `<cluster>-<pool>`. Testez l'effet d'un changement de `cpuCount`, `imageName` etc. sur un cluster jetable avant de l'appliquer en production.
- **Secrets en vrai GitOps** : le script sert aux tests. En production, gérez-les avec External Secrets, Sealed Secrets ou SOPS.
- **ServiceAccount orphelin** : le kubeconfig du cloud provider est lié à un ServiceAccount sur Harvester. Après suppression du cluster, supprimez le ServiceAccount orphelin côté Harvester.
- **Cloud credential obsolète** : si vous réimportez Harvester dans Rancher, recréez le cloud credential (voir [rancher/rancher#53642](https://github.com/rancher/rancher/issues/53642)).
