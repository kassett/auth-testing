

## Description

This goal of this repository is to setup and test various open source tools for
authentication, including Keycloak, Authentik, Ory, and Zitadel.

This repository uses NIX and direnv for easy development setup. If you have these tools installed,
simply run `direnv allow` to setup your development environment. Otherwise, you will need
* k3d
* Helmfile
* kubectl
* docker

### Start up the cluster

```shell
k3d cluster create autheval \
  --image rancher/k3s:v1.35.3-k3s1 \
  --servers 1 \
  --agents 2 \
  -p "80:80@loadbalancer" \
  -p "443:443@loadbalancer" \
  --k3s-arg "--disable=traefik@server:*" \
  --volume "$PWD/bootstrap/coredns-custom.yaml:/var/lib/rancher/k3s/server/manifests/coredns-custom.yaml@server:0"
  ```

### Bootstrap the local network

The first step to doing this is running the local CoreDNS server.

```shell
cd boostrap
docker-compose -d
```

The next step is to apply the Helmfile, which will setup EnvoyProxy Gateway and Cert-Manager.
```shell
cd bootstrap
helmfile apply -f helmfile.yaml
```

And finally, run the shell script to add the cluster cert to your local truststore, as well
as configure your computer to recognize your local DNS server.
```shell
cd bootstrap
./install-local-ca.sh
```

### Verification of bootstrap
The bootstrap setup configures httpbin at https://httpbin.autheval.test. If that is routable,
all of these steps have succeeded.