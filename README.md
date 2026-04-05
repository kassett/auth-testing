

## Description

This goal of this repository is to setup and test various open source tools for
authentication, including Keycloak, Authentik, Ory, and Zitadel.

### Start up the cluster

```shell
k3d cluster create kassett \
  --image rancher/k3s:v1.35.3-k3s1 \
  --servers 1 \
  --agents 2 \
  -p "80:80@loadbalancer" \
  -p "443:443@loadbalancer" \
  --k3s-arg "--disable=traefik@server:*"
```