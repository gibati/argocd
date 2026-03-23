#!/bin/bash

set -e

KEYCLOAK_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASS="admin123"
REALM="argocd"

CLIENT_ADMIN="argocd-admin"
CLIENT_RO="argocd-ro"
CLIENT_SSO="argocd"

SECRET_ADMIN=""
SECRET_RO=""
SECRET_SSO=""

echo "🔑 Pegando token admin..."

ADMIN_TOKEN=$(curl -s \
  -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$ADMIN_USER" \
  -d "password=$ADMIN_PASS" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r .access_token)

echo "🌍 Criando realm..."

curl -s -X POST "$KEYCLOAK_URL/admin/realms" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"realm\": \"$REALM\", \"enabled\": true}" || true

echo "👥 Criando roles..."

for ROLE in gs_argocd_admin gs_argocd_ro; do
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM/roles" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$ROLE\"}" || true
done

########################################
# CLIENTES ADMIN / RO
########################################

create_client() {
  CLIENT_ID=$1
  ROLE_NAME=$2

  echo "📦 Criando client $CLIENT_ID..."

  curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM/clients" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"clientId\": \"$CLIENT_ID\",
      \"enabled\": true,
      \"protocol\": \"openid-connect\",
      \"publicClient\": false,
      \"serviceAccountsEnabled\": true,
      \"standardFlowEnabled\": false,
      \"directAccessGrantsEnabled\": false
    }" || true

  CLIENT_UUID=$(curl -s \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$KEYCLOAK_URL/admin/realms/$REALM/clients?clientId=$CLIENT_ID" | jq -r '.[0].id')

  CLIENT_SECRET=$(curl -s \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$KEYCLOAK_URL/admin/realms/$REALM/clients/$CLIENT_UUID/client-secret" | jq -r .value)

  SERVICE_ACCOUNT_ID=$(curl -s \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$KEYCLOAK_URL/admin/realms/$REALM/clients/$CLIENT_UUID/service-account-user" | jq -r .id)

  ROLE=$(curl -s \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$KEYCLOAK_URL/admin/realms/$REALM/roles/$ROLE_NAME")

  curl -s -X POST \
    "$KEYCLOAK_URL/admin/realms/$REALM/users/$SERVICE_ACCOUNT_ID/role-mappings/realm" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "[$ROLE]" || true

  # audience
  curl -s -X POST \
    "$KEYCLOAK_URL/admin/realms/$REALM/clients/$CLIENT_UUID/protocol-mappers/models" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"audience-$CLIENT_ID\",
      \"protocol\": \"openid-connect\",
      \"protocolMapper\": \"oidc-audience-mapper\",
      \"config\": {
        \"included.client.audience\": \"argocd\",
        \"access.token.claim\": \"true\"
      }
    }" || true

  # roles mapper
  curl -s -X POST \
    "$KEYCLOAK_URL/admin/realms/$REALM/clients/$CLIENT_UUID/protocol-mappers/models" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"roles\",
      \"protocol\": \"openid-connect\",
      \"protocolMapper\": \"oidc-usermodel-realm-role-mapper\",
      \"config\": {
        \"multivalued\": \"true\",
        \"claim.name\": \"roles\",
        \"access.token.claim\": \"true\",
        \"id.token.claim\": \"true\"
      }
    }" || true

  if [ "$CLIENT_ID" == "$CLIENT_ADMIN" ]; then
    SECRET_ADMIN=$CLIENT_SECRET
  elif [ "$CLIENT_ID" == "$CLIENT_RO" ]; then
    SECRET_RO=$CLIENT_SECRET
  fi
}

########################################
# CLIENT SSO
########################################

create_client_sso() {
  echo "📦 Criando client SSO ($CLIENT_SSO)..."

  curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM/clients" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"clientId\": \"$CLIENT_SSO\",
      \"enabled\": true,
      \"protocol\": \"openid-connect\",
      \"publicClient\": false,
      \"standardFlowEnabled\": true,
      \"serviceAccountsEnabled\": false,
      \"redirectUris\": [\"*\"]
    }" || true

  CLIENT_UUID=$(curl -s \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$KEYCLOAK_URL/admin/realms/$REALM/clients?clientId=$CLIENT_SSO" | jq -r '.[0].id')

  SECRET_SSO=$(curl -s \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$KEYCLOAK_URL/admin/realms/$REALM/clients/$CLIENT_UUID/client-secret" | jq -r .value)

  # roles mapper
  curl -s -X POST \
    "$KEYCLOAK_URL/admin/realms/$REALM/clients/$CLIENT_UUID/protocol-mappers/models" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"roles\",
      \"protocol\": \"openid-connect\",
      \"protocolMapper\": \"oidc-usermodel-realm-role-mapper\",
      \"config\": {
        \"multivalued\": \"true\",
        \"claim.name\": \"roles\",
        \"access.token.claim\": \"true\",
        \"id.token.claim\": \"true\"
      }
    }" || true
}

########################################
# EXECUÇÃO
########################################

create_client "$CLIENT_ADMIN" "gs_argocd_admin"
create_client "$CLIENT_RO" "gs_argocd_ro"
create_client_sso

########################################
# OUTPUT FINAL
########################################

echo ""
echo "================ RESULTADO FINAL ================"
echo ""

echo "clientId: argocd"
echo "clientSecret: $SECRET_SSO"
echo ""

echo "clientId: argocd-admin"
echo "clientSecret: $SECRET_ADMIN"
echo ""

echo "clientId: argocd-ro"
echo "clientSecret: $SECRET_RO"
echo ""

echo "================================================"