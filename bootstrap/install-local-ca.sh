#!/bin/bash
set -euo pipefail

DOMAIN="${DOMAIN:-autheval.test}"
RESOLVER_DIR="/etc/resolver"
RESOLVER_FILE="${RESOLVER_DIR}/${DOMAIN}"
CA_SECRET_NAMESPACE="${CA_SECRET_NAMESPACE:-cert-manager}"
CA_SECRET_NAME="${CA_SECRET_NAME:-local-root-ca-secret}"
CA_CERT_PATH="${CA_CERT_PATH:-/tmp/local-root-ca.crt}"
KEYCHAIN="${KEYCHAIN:-/Library/Keychains/System.keychain}"

echo "Configuring macOS resolver for ${DOMAIN}..."
sudo mkdir -p "${RESOLVER_DIR}"
echo "nameserver 127.0.0.1" | sudo tee "${RESOLVER_FILE}" >/dev/null

echo "Flushing macOS DNS caches..."
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder || true

echo "Exporting local CA from Kubernetes secret ${CA_SECRET_NAMESPACE}/${CA_SECRET_NAME}..."
kubectl -n "${CA_SECRET_NAMESPACE}" get secret "${CA_SECRET_NAME}" \
  -o jsonpath='{.data.ca\.crt}' | base64 -d > "${CA_CERT_PATH}"

echo "Removing any existing local-root-ca certificate from System keychain..."
sudo security delete-certificate -c "local-root-ca" "${KEYCHAIN}" 2>/dev/null || true

echo "Installing CA into System keychain..."
sudo security add-trusted-cert \
  -d \
  -r trustRoot \
  -p ssl \
  -k "${KEYCHAIN}" \
  "${CA_CERT_PATH}"

echo
echo "Done."
echo "Resolver file: ${RESOLVER_FILE}"
echo "CA cert file:   ${CA_CERT_PATH}"
echo
echo "Verify with:"
echo "  scutil --dns | grep -A2 ${DOMAIN}"
echo "  dig @127.0.0.1 httpbin.${DOMAIN}"
echo "  curl https://httpbin.${DOMAIN}/get"
echo
echo "You may need to fully restart Chrome."