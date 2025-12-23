#!/bin/bash
set -e
source .env
CLIENT_ID=${FASTMCP_CLIENT_APP_ID}
CLIENT_SECRET=${FASTMCP_CLIENT_CLIENT_SECRET}
TENANT_ID=${AZURE_TENANT_ID}
SERVER_APP_ID=${FASTMCP_SERVER_APP_ID}  

# Get token
TOKEN=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=api://$SERVER_APP_ID/.default" \
  -d "grant_type=client_credentials" | jq -r .access_token)

echo "Token: $TOKEN"

# Decode and print token claims
if [ "$TOKEN" != "null" ] && [ -n "$TOKEN" ]; then
  echo "🔍 Token Claims:"
  PAYLOAD=$(echo $TOKEN | cut -d'.' -f2)
  # Add padding if needed
  PADDING=$((${#PAYLOAD} % 4))
  if [ $PADDING -ne 0 ]; then
    PAYLOAD="${PAYLOAD}$(printf '=%.0s' $(seq 1 $((4 - PADDING))))"
  fi
  DECODED=$(echo $PAYLOAD | base64 -d 2>/dev/null)
  
  echo "  aud (audience): $(echo $DECODED | jq -r .aud)"
  echo "  azp (authorized party): $(echo $DECODED | jq -r .azp)"
  echo "  scp (scopes): $(echo $DECODED | jq -r .scp)"
  echo "  azpacr: $(echo $DECODED | jq -r .azpacr)"
  echo ""
fi

# Test MCP server
curl -X POST http://localhost:8000/mcp \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'