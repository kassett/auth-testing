terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.12.1"
    }

    kubectl = {
      source  = "alekc/kubectl"
    }
  }
}

provider "authentik" {
  url = "https://authentik.autheval.test"
}

provider "kubectl" {
  load_config_file = true
  config_path      = "~/.kube/config"
  config_context   = "k3d-autheval"
}

data "authentik_flow" "default_authorization_flow" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default_invalidation_flow" {
  slug = "default-provider-invalidation-flow"
}

resource "authentik_provider_oauth2" "httpbin" {
  name               = "httpbin-oauth2"
  client_id          = "httpbin-oauth2"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://httpbin.autheval.test/oauth2/callback"
    }
  ]
}

resource "authentik_application" "httpbin" {
  name              = "httpbin"
  slug              = "httpbin"
  protocol_provider = authentik_provider_oauth2.httpbin.id
}

resource "authentik_policy_expression" "allow_all" {
  name       = "allow-all"
  expression = "return True"
}

resource "authentik_policy_binding" "httpbin_policy" {
  target = authentik_application.httpbin.uuid
  policy = authentik_policy_expression.allow_all.id
  order  = 0
}

resource "kubectl_manifest" "httpbin_creds" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "httpbin-creds"
      namespace = "demo"
    }
    data = {
      client-secret = base64encode(authentik_provider_oauth2.httpbin.client_secret)
    }
  })
}

resource "kubectl_manifest" "authentik_oidc_backend" {
  yaml_body = yamlencode({
    apiVersion = "gateway.envoyproxy.io/v1alpha1"
    kind       = "Backend"
    metadata = {
      name      = "authentik-oidc"
      namespace = "cert-manager"
    }
    spec = {
      endpoints = [
        {
          fqdn = {
            hostname = "authentik.autheval.test"
            port     = 443
          }
        }
      ]
    }
  })
}

resource "kubectl_manifest" "authentik_oidc_tls" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "BackendTLSPolicy"
    metadata = {
      name      = "authentik-oidc-tls"
      namespace = "cert-manager"
    }
    spec = {
      targetRefs = [
        {
          group = "gateway.envoyproxy.io"
          kind  = "Backend"
          name  = "authentik-oidc"
        }
      ]
      validation = {
        hostname = "authentik.autheval.test"
        caCertificateRefs = [
          {
            group = ""
            kind  = "Secret"
            name  = "local-root-ca-secret"
          }
        ]
      }
    }
  })

  depends_on = [kubectl_manifest.authentik_oidc_backend]
}

resource "kubectl_manifest" "httpbin_oidc_security_policy" {
  yaml_body = yamlencode({
    apiVersion = "gateway.envoyproxy.io/v1alpha1"
    kind       = "SecurityPolicy"
    metadata = {
      name      = "httpbin-oidc"
      namespace = "demo"
    }
    spec = {
      targetRefs = [
        {
          group = "gateway.networking.k8s.io"
          kind  = "HTTPRoute"
          name  = "httpbin"
        }
      ]
      oidc = {
        provider = {
          issuer = "https://authentik.autheval.test/application/o/httpbin"
          backendRefs = [
            {
              group     = "gateway.envoyproxy.io"
              kind      = "Backend"
              name      = "authentik-oidc"
              namespace = "cert-manager"
              port      = 443
            }
          ]
        }
        clientID = authentik_provider_oauth2.httpbin.client_id
        clientSecret = {
          name = "httpbin-creds"
        }
        redirectURL = "https://httpbin.autheval.test/oauth2/callback"
        scopes = [
          "openid",
          "profile",
          "email",
        ]
      }
    }
  })

  depends_on = [
    kubectl_manifest.httpbin_creds,
    kubectl_manifest.authentik_oidc_backend,
  ]
}

resource "kubectl_manifest" "allow_demo_securitypolicy_to_backend" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "ReferenceGrant"
    metadata = {
      name      = "allow-demo-securitypolicy-to-backend"
      namespace = "cert-manager"
    }
    spec = {
      from = [
        {
          group     = "gateway.envoyproxy.io"
          kind      = "SecurityPolicy"
          namespace = "demo"
        }
      ]
      to = [
        {
          group = "gateway.envoyproxy.io"
          kind  = "Backend"
        }
      ]
    }
  })
}

output "client_id" {
  value = authentik_provider_oauth2.httpbin.client_id
}

output "client_secret" {
  value     = authentik_provider_oauth2.httpbin.client_secret
  sensitive = true
}