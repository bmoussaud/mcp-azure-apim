#!/bin/bash

set -euo pipefail

# Script: Assign Agent ID Administrator Role to Current User
# Usage: ./assign_agent_id_adminstration_role_to_current_user.sh [--tenant-id <TENANT_ID>]

# Parse command-line arguments
TENANT_ID=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --tenant-id)
            TENANT_ID="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--tenant-id <TENANT_ID>]"
            exit 1
            ;;
    esac
done

# If TENANT_ID is not provided, retrieve it from current subscription
if [ -z "$TENANT_ID" ]; then
    echo "TENANT_ID not provided. Retrieving from current Azure subscription..."
    TENANT_ID=$(az account show --query tenantId -o tsv)
    if [ -z "$TENANT_ID" ]; then
        echo "Error: Could not retrieve tenant ID. Please provide it with --tenant-id or run 'az login' first."
        exit 1
    fi
fi

echo "Using Tenant ID: $TENANT_ID"

# Get the role definition ID
ROLE_ID=$(az rest --method GET --url 'https://graph.microsoft.com/v1.0/directoryRoles' --query "value[?displayName=='Agent ID Administrator'].id" -o tsv)

if [ -z "$ROLE_ID" ]; then
    echo "Role 'Agent ID Administrator' is not instantiated. Activating it first..."

    # Get role template ID
    TEMPLATE_ID=$(az rest --method GET --url 'https://graph.microsoft.com/v1.0/directoryRoleTemplates' --query "value[?displayName=='Agent ID Administrator'].id" -o tsv)
    
    if [ -z "$TEMPLATE_ID" ]; then
        echo "Error: Could not find Agent ID Administrator role template."
        exit 1
    fi
    
    echo "Role Template ID: $TEMPLATE_ID"

    echo "Activating the Agent ID Administrator role..."
    az rest --method POST --url 'https://graph.microsoft.com/v1.0/directoryRoles' \
        --body "{\"roleTemplateId\": \"$TEMPLATE_ID\"}"

    # Retrieve the newly created role ID
    ROLE_ID=$(az rest --method GET --url 'https://graph.microsoft.com/v1.0/directoryRoles' --query "value[?displayName=='Agent ID Administrator'].id" -o tsv)
    
    if [ -z "$ROLE_ID" ]; then
        echo "Error: Failed to activate Agent ID Administrator role."
        exit 1
    fi
fi

echo "Assigning Agent ID Administrator role to current user..."
USER_ID=$(az ad signed-in-user show --query id -o tsv)

if [ -z "$USER_ID" ]; then
    echo "Error: Could not retrieve current user ID."
    exit 1
fi

echo "Assigning role to User ID: $USER_ID"
az rest --method POST --url "https://graph.microsoft.com/v1.0/directoryRoles/$ROLE_ID/members/\$ref" \
    --body "{\"@odata.id\": \"https://graph.microsoft.com/v1.0/users/$USER_ID\"}"

echo ""
echo "Successfully assigned Agent ID Administrator role to current user!"
echo ""
echo "Available directory roles:"
az rest --method GET --url 'https://graph.microsoft.com/v1.0/directoryRoles' --query "value[].displayName" -o table
