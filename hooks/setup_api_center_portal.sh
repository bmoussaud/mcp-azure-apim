#!/bin/bash
set -euo pipefail

# This script configures the Azure API Center portal after deployment
# It creates an Entra ID app registration and configures the portal settings

echo "Setting up API Center Portal..."

# Get values from azd environment
API_CENTER_NAME=$(azd env get-value API_CENTER_NAME)
LOCATION=$(azd env get-value AZURE_LOCATION)
RESOURCE_GROUP=$(azd env get-value AZURE_RESOURCE_GROUP)

if [ -z "$API_CENTER_NAME" ]; then
    echo "ERROR: API_CENTER_NAME not found in azd environment"
    exit 1
fi

echo "API Center: $API_CENTER_NAME"
echo "Location: $LOCATION"
echo "Resource Group: $RESOURCE_GROUP"

# Construct the portal redirect URI
PORTAL_REDIRECT_URI="https://${API_CENTER_NAME}.portal.${LOCATION}.azure-apicenter.ms"
echo "Portal URL: $PORTAL_REDIRECT_URI"

# Check if app registration already exists
APP_DISPLAY_NAME="${API_CENTER_NAME}-apic-portal"
echo "Checking for existing app registration: $APP_DISPLAY_NAME"

EXISTING_APP_ID=$(az ad app list --display-name "$APP_DISPLAY_NAME" --query "[0].appId" -o tsv)

if [ -n "$EXISTING_APP_ID" ]; then
    echo "App registration already exists with ID: $EXISTING_APP_ID"
    CLIENT_ID="$EXISTING_APP_ID"
else
    echo "Creating new Entra ID app registration..."
    
    # Create the app registration for API Center portal
    CLIENT_ID=$(az ad app create \
        --display-name "$APP_DISPLAY_NAME" \
        --sign-in-audience "AzureADMyOrg" \
        --web-redirect-uris "$PORTAL_REDIRECT_URI" \
        --enable-id-token-issuance true \
        --query "appId" -o tsv)
    
    echo "Created app registration with Client ID: $CLIENT_ID"
    
    # Add SPA platform with redirect URIs
    az ad app update \
        --id "$CLIENT_ID" \
        --spa-redirect-uris "$PORTAL_REDIRECT_URI"
    
    echo "Configured SPA redirect URI"
fi

# Optional: Add VS Code extension redirect URIs
echo "Adding VS Code extension redirect URIs..."
az ad app update \
    --id "$CLIENT_ID" \
    --public-client-redirect-uris \
        "https://vscode.dev/redirect" \
        "http://localhost" \
        "ms-appx-web://Microsoft.AAD.BrokerPlugin/${CLIENT_ID}" \
    || echo "Warning: Could not add public client redirect URIs (may already exist)"

# Get the current user's object ID to assign API Center Data Reader role
CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv)
echo "Current user ID: $CURRENT_USER_ID"

# Get the API Center resource ID
API_CENTER_ID=$(az apic show \
    --name "$API_CENTER_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query id -o tsv)

echo "API Center Resource ID: $API_CENTER_ID"

# Assign Azure API Center Data Reader role to current user
# Role definition ID for "Azure API Center Data Reader": 71522526-b88f-4d52-b57f-d31fc3546d0d
echo "Assigning Azure API Center Data Reader role to current user..."
az role assignment create \
    --assignee "$CURRENT_USER_ID" \
    --role "Azure API Center Data Reader" \
    --scope "$API_CENTER_ID" \
    --output none \
    || echo "Warning: Role assignment may already exist"

# Save the client ID to azd environment for reference
azd env set API_CENTER_PORTAL_CLIENT_ID "$CLIENT_ID"

echo ""
echo "✅ API Center Portal setup complete!"
echo ""
echo "Portal Configuration:"
echo "  Portal URL: $PORTAL_REDIRECT_URI"
echo "  Client ID: $CLIENT_ID"
echo ""
echo "Next steps:"
echo "1. Go to Azure Portal -> API Center -> API Center portal -> Settings"
echo "2. On the 'Identity provider' tab, select 'Start set up'"
echo "3. On the 'Manual' tab, enter Client ID: $CLIENT_ID"
echo "4. Confirm Redirect URI: $PORTAL_REDIRECT_URI"
echo "5. Select 'Save + publish'"
echo ""
echo "Or use the Azure CLI to configure the portal (if API available):"
echo "  az apic portal update --service-name $API_CENTER_NAME --resource-group $RESOURCE_GROUP --identity-provider-client-id $CLIENT_ID"
echo ""
