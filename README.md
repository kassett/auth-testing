

## Description

This goal of this repository is to setup and test various open source tools for
authentication, including Keycloak, Authentik, Ory, and Zitadel.

### Start up the cluster

```shell
k3d cluster create auth-testing \
  --agents 1 \
  --port "8080:80@loadbalancer" \
  --port "8443:443@loadbalancer" \
  --k3s-arg "--disable=traefik@server:*"
```

### Apply the helmfile

```shell
cd authentik && helmfile apply
```

### Accessing services

The k3d loadbalancer maps host port `8080` → gateway port `80`. Add entries to `/etc/hosts` for each service hostname:

```
127.0.0.1 httpbin.localhost
```

Then access via `http://httpbin.localhost:8080`.