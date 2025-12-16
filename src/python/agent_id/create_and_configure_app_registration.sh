#!/usr/bin/env bash

set -euo pipefail

# create_app_registration.sh
# Create an Entra app registration (client ID) and a client secret via Azure CLI.
# Requirements: az CLI logged in with permissions to create app registrations (e.g., Application Administrator).
# Usage:
#   ./create_app_registration.sh --display-name "My App" [--secret-name "default"] [--years 1]
#
# Outputs:
#   APP_ID      - Application (client) ID
#   TENANT_ID   - Tenant ID
#   SECRET      - Client secret value (store securely!)

DISPLAY_NAME=""
SECRET_NAME="default"
YEARS=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --display-name)
      DISPLAY_NAME="$2"; shift 2 ;;
    --secret-name)
      SECRET_NAME="$2"; shift 2 ;;
    --years)
      YEARS="$2"; shift 2 ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 --display-name <name> [--secret-name <name>] [--years <years>]" >&2
      exit 1 ;;
  esac
done

if [[ -z "$DISPLAY_NAME" ]]; then
  echo "--display-name is required" >&2
  exit 1
fi

echo "Creating app registration: $DISPLAY_NAME"
APP_JSON=$(az ad app create \
  --display-name "$DISPLAY_NAME" \
  --sign-in-audience AzureADMyOrg \
  --query '{appId:appId, id:id}' -o json)

APP_ID=$(echo "$APP_JSON" | jq -r '.appId')
APP_OBJECT_ID=$(echo "$APP_JSON" | jq -r '.id')
TENANT_ID=$(az account show --query tenantId -o tsv)

if [[ -z "$APP_ID" ]]; then
  echo "Failed to create app registration" >&2
  exit 1
fi

echo "Ensuring service principal exists..."
az ad sp create --id "$APP_ID" >/dev/null

echo "Creating client secret (name=$SECRET_NAME, years=$YEARS)..."
SECRET_JSON=$(az ad app credential reset \
  --id "$APP_ID" \
  --display-name "$SECRET_NAME" \
  --years "$YEARS" \
  --query '{clientSecret:password}' -o json)

SECRET_VALUE=$(echo "$SECRET_JSON" | jq -r '.clientSecret')

if [[ -z "$SECRET_VALUE" || "$SECRET_VALUE" == "null" ]]; then
  echo "Failed to create client secret" >&2
  exit 1
fi

echo ""
echo "App registration created. Store these values securely:"
echo "  APP_ID:      $APP_ID"
echo "  TENANT_ID:   $TENANT_ID"
echo "  SECRET:      $SECRET_VALUE"
echo ""
echo "Tip: export AZURE_CLIENT_ID=$APP_ID and AZURE_CLIENT_SECRET=<secret> for client credentials auth."

echo "Add the app roles (Graph appId is 00000003-0000-0000-c000-000000000000):"
GRAPH_APP_ID="00000003-0000-0000-c000-000000000000"

# Resolve Graph app role IDs for the Agent Identity Blueprint permissions
echo "Fetching app role GUIDs from Microsoft Graph service principal..."
GRAPH_SP_OBJECT_ID=$(az ad sp show --id "$GRAPH_APP_ID" --query id -o tsv)

APP_ROLE_MAP=$(az rest --method GET --url "https://graph.microsoft.com/v1.0/servicePrincipals/$GRAPH_SP_OBJECT_ID?\$select=appRoles" \
  --query "appRoles[?value=='AgentIdentityBlueprint.Create' || value=='AgentIdentityBlueprint.AddRemoveCreds.All' || value=='AgentIdentityBlueprint.ReadWrite.All' || value=='Application.ReadWrite.All'].{value:value,id:id}" -o json)

echo $APP_ROLE_MAP | jq

if [[ -z "$APP_ROLE_MAP" || "$APP_ROLE_MAP" == "[]" ]]; then
  echo "WARNING: Could not find Agent Identity Blueprint roles in Graph API. These may be beta-only roles." >&2
  echo "Skipping permission assignment. You may need to add these manually in the Azure Portal." >&2
else
  declare -A ROLE_IDS
  while IFS= read -r line; do
    VALUE=$(echo "$line" | jq -r '.value')
    ID=$(echo "$line" | jq -r '.id')
    ROLE_IDS[$VALUE]=$ID
  done < <(echo "$APP_ROLE_MAP" | jq -c '.[]')

  for ROLE in Application.ReadWrite.All AgentIdentityBlueprint.Create AgentIdentityBlueprint.AddRemoveCreds.All AgentIdentityBlueprint.ReadWrite.All; do
    if [[ -z "${ROLE_IDS[$ROLE]:-}" ]]; then
      echo "Error: Could not find app role ID for $ROLE" >&2
      exit 1
    fi
    ROLE_ID="${ROLE_IDS[$ROLE]}"
    echo "Adding permission: $ROLE ($ROLE_ID)"
    az ad app permission add --id "$APP_ID" --api "$GRAPH_APP_ID" --api-permissions "$ROLE_ID=Role"
    echo "Granting permission: $ROLE"
    az ad app permission grant --id "$APP_ID" --api "$GRAPH_APP_ID" --scope "$ROLE_ID"

  done

  echo ""
  echo "Grant admin consent for the app (requires sufficient directory role)..."
  az ad app permission admin-consent --id "$APP_ID"
fi

./assign_agent_id_admin_role_to_sp.sh "$APP_ID"

echo ""
echo "Verifying granted app roles via Microsoft Graph API..."
SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)

# Query app role assignments to verify permissions were granted
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_OBJECT_ID/appRoleAssignments" \
  --query "value[].{resource:resourceDisplayName,roleId:appRoleId}" -o tsv

echo ""
echo "App registration created. Store these values securely:"
echo "CLIENT_ID=$APP_ID"
echo "TENANT_ID=$TENANT_ID"
echo "CLIENT_SECRET=$SECRET_VALUE"
echo ""
echo "Tip: export AZURE_CLIENT_ID=$APP_ID and AZURE_CLIENT_SECRET=<secret> for client credentials auth."