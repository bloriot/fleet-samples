#!/usr/bin/env bash
# Crée hors Git les deux secrets sensibles requis par le cluster :
#   credential     -> cloud credential Harvester (cattle-global-data)
#   cloudprovider  -> kubeconfig du cloud provider Harvester (fleet-default)
#
# Prérequis : kubectl pointant sur le cluster local de Rancher, curl, jq.
#
# Variables :
#   RANCHER_URL              ex. https://rancher.example.com
#   RANCHER_TOKEN            token API Rancher (Bearer), ex. token-abcde:xxxxxxxx
#   HARVESTER_CLUSTER_NAME   nom du cluster Harvester importé dans Rancher
#   CLUSTER_NAME             nom du cluster à créer (= cluster.name du chart)
#   VM_NAMESPACE             namespace Harvester des VMs (= machineDefaults.vmNamespace)
#   CRED_NAME                nom du cloud credential (défaut : harvester-cloud-credential)
#   CP_SECRET_NAME           nom du secret cloud provider (défaut : <CLUSTER_NAME>-cloudprovider)
set -euo pipefail

: "${RANCHER_URL:?}" "${RANCHER_TOKEN:?}" "${HARVESTER_CLUSTER_NAME:?}"
RANCHER_URL="${RANCHER_URL%/}"
CRED_NAME="${CRED_NAME:-harvester-cloud-credential}"

harvester_cluster_id() {
  kubectl get clusters.management.cattle.io -o json \
    | jq -r --arg n "$HARVESTER_CLUSTER_NAME" '.items[] | select(.spec.displayName==$n) | .metadata.name'
}

create_credential() {
  local id kubeconfig
  id="$(harvester_cluster_id)"
  [ -n "$id" ] || { echo "Cluster Harvester '$HARVESTER_CLUSTER_NAME' introuvable dans Rancher" >&2; exit 1; }

  kubeconfig="$(curl -sfk -X POST -H "Authorization: Bearer ${RANCHER_TOKEN}" \
    "${RANCHER_URL}/v3/clusters/${id}?action=generateKubeconfig" | jq -r .config)"

  kubectl create secret generic "$CRED_NAME" -n cattle-global-data \
    --from-literal=harvestercredentialConfig-clusterId="$id" \
    --from-literal=harvestercredentialConfig-clusterType=imported \
    --from-literal=harvestercredentialConfig-kubeconfigContent="$kubeconfig" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl label secret "$CRED_NAME" -n cattle-global-data --overwrite cattle.io/creator=norman
  kubectl annotate secret "$CRED_NAME" -n cattle-global-data --overwrite \
    field.cattle.io/name="$CRED_NAME" provisioning.cattle.io/driver=harvester
  echo "Cloud credential cattle-global-data/${CRED_NAME} créé"
}

create_cloudprovider() {
  : "${CLUSTER_NAME:?}" "${VM_NAMESPACE:?}"
  local id kubeconfig name
  id="$(harvester_cluster_id)"
  [ -n "$id" ] || { echo "Cluster Harvester '$HARVESTER_CLUSTER_NAME' introuvable dans Rancher" >&2; exit 1; }
  name="${CP_SECRET_NAME:-${CLUSTER_NAME}-cloudprovider}"

  kubeconfig="$(curl -sfk -X POST -H "Authorization: Bearer ${RANCHER_TOKEN}" -H 'Content-Type: application/json' \
    -d "{\"clusterRoleName\":\"harvesterhci.io:cloudprovider\",\"namespace\":\"${VM_NAMESPACE}\",\"serviceAccountName\":\"${CLUSTER_NAME}\"}" \
    "${RANCHER_URL}/k8s/clusters/${id}/v1/harvester/kubeconfig" | jq -r .)"

  kubectl create secret generic "$name" -n fleet-default \
    --from-literal=credential="$kubeconfig" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl annotate secret "$name" -n fleet-default --overwrite \
    v2prov-secret-authorized-for-cluster="$CLUSTER_NAME"
  echo "Secret fleet-default/${name} créé (autorisé pour le cluster ${CLUSTER_NAME})"
}

case "${1:-}" in
  credential)    create_credential ;;
  cloudprovider) create_cloudprovider ;;
  all)           create_credential; create_cloudprovider ;;
  *) echo "Usage: $0 {credential|cloudprovider|all}" >&2; exit 2 ;;
esac
