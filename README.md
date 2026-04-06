

## Description

This goal of this repository is to setup and test various open source tools for
authentication, including Keycloak, Authentik, Ory, and Zitadel.

This repository uses NIX and direnv for easy development setup. If you have these tools installed,
simply run `direnv allow` to setup your development environment. Otherwise, you will need
* k3d
* Helmfile
* kubectl
* docker

### Development Setup

#### Cluster Startup

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

While the above command can be customized, it is important to address the following things:
* If there is no port-forwarding over 80/443, load balancers
    configured by Envoy Gateway will not be routable.
* If Traefik is not disabled, the load balancer pods from Envoy Gateway
    will have no ports to claim, and therefore the pods will be forever stuck in pending.
* If coredns-custom.yaml is not injected into the cluster, the cluster will
    not respect the local DNS server.
* If the default Rancher image is used, there will not be any support
    for injecting custom CoreDNS rules.

#### Bootstrap local ingress

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

#### Verification of bootstrap
The bootstrap setup configures httpbin at https://httpbin.autheval.test. If that is routable,
all of these steps have succeeded.

### Authentik

As I understand it, Authentik claims to be the easy-to-use version of Keycloak.
It has native to support for all the connectors that you might want, including
SSO, SAML, SCIM, etc. Its community is significantly smaller than that of Keycloak's,
but if it is that much easier to use, that might not be a problem.

#### Setup

After running the bootstrapping step, run the following:

```shell
cd authentik
helmfile apply -f helmfile.yaml
```

This step will set up a Postgres database in the `postgres` namespace,
as well as Authentik in the `authentik` namespace. Note that there is no way 
to configure Authentik's credentials via the Helm chart. Instead, you must log into
https://authentik.autheval.test/if/flow/initial-setup/ and configure the Admin username and password.

After configuring the username and password, navigate to the admin interface
and create a token. This token will expire after 30 minutes, but that is certainly
enough for the initial setup.

To create the SecurityPolicy, export this token
as `AUTHENTIK_TOKEN=<TOKEN>` and run 

```shell
terraform apply -auto-approve
```

The next time that you navigate to https://httpbin.autheval.test, you 
will be redirected to Authentik for login.