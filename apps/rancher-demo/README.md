# Rancher Demo

Application de [janeczku/rancher-demo](https://github.com/janeczku/rancher-demo) : une icône par réplica, pratique pour montrer le scaling et le load balancing.

Déployée par le `GitRepo` `gitrepos/rancher-demo.yaml` sur tous les clusters portant le label `demo-app=rancher-demo`.

Accès : `http://<ip-d-un-noeud>:30080`.

Pour la démo, modifiez dans `values.yaml` :
- `replicaCount` : le nombre d'icônes change après un `git push`.
- `app.pets` (`cows`, `chameleons`, `cowmeleons`) et `app.color`.
