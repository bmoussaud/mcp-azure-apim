#!/bin/bash
set -euo pipefail

# Script to assign Agent ID Administrator role to a service principal
# This role is required to create Agent Identity Blueprints
# Usage: ./assign_agent_id_admin_role_to_sp.sh <CLIENT_ID> 
# Requirements: az CLI logged in with sufficient permissions (e.g., Global Administrator or Privileged Role Administrator)
# Outputs:
#   Confirmation of role assignment
CLIENT_ID=${1:-}
echo "Assigning Agent ID Administrator role to service principal: ${CLIENT_ID}"

# Get the service principal object ID
echo "Looking up service principal object ID..."
SP_OBJECT_ID=$(az ad sp show --id "${CLIENT_ID}" --query id -o tsv)
echo "Service Principal Object ID: ${SP_OBJECT_ID}"

# Agent ID Administrator role template ID (constant across all tenants)
ROLE_TEMPLATE_ID="db506228-d27e-4b7d-95e5-295956d6615f"

# Check if the role is activated in the tenant
echo "Checking if Agent ID Administrator role is activated in tenant..."
ROLE_ID=$(az rest --method GET \
    --url "https://graph.microsoft.com/v1.0/directoryRoles?\$filter=roleTemplateId eq '${ROLE_TEMPLATE_ID}'" \
    --query "value[0].id" -o tsv 2>/dev/null || echo "")

if [ -z "$ROLE_ID" ] || [ "$ROLE_ID" == "null" ]; then
    echo "Role not activated. Activating Agent ID Administrator role in tenant..."
    ROLE_ID=$(az rest --method POST \
        --url "https://graph.microsoft.com/v1.0/directoryRoles" \
        --body "{\"roleTemplateId\": \"${ROLE_TEMPLATE_ID}\"}" \
        --query "id" -o tsv)
    echo "Activated role with ID: ${ROLE_ID}"
else
    echo "Role already activated with ID: ${ROLE_ID}"
fi

# Check if service principal already has the role
echo "Checking if service principal already has the role..."
EXISTING_ASSIGNMENT=$(az rest --method GET \
    --url "https://graph.microsoft.com/v1.0/directoryRoles/${ROLE_ID}/members" \
    --query "value[?id=='${SP_OBJECT_ID}'].id" -o tsv 2>/dev/null || echo "")

if [ -n "$EXISTING_ASSIGNMENT" ]; then
    echo "Service principal already has Agent ID Administrator role assigned"
else
    echo "Assigning Agent ID Administrator role to service principal..."
    az rest --method POST \
        --url "https://graph.microsoft.com/v1.0/directoryRoles/${ROLE_ID}/members/\$ref" \
        --body "{\"@odata.id\": \"https://graph.microsoft.com/v1.0/directoryObjects/${SP_OBJECT_ID}\"}"
    echo "Successfully assigned Agent ID Administrator role to service principal"
fi

echo ""
echo "Verification:"
az rest --method GET \
    --url "https://graph.microsoft.com/v1.0/directoryRoles/${ROLE_ID}/members" \
    --query "value[?id=='${SP_OBJECT_ID}'].{id:id,displayName:displayName,servicePrincipalType:servicePrincipalType}" \
    -o table

echo ""
echo "✓ Agent ID Administrator role has been assigned to service principal ${CLIENT_ID}"
