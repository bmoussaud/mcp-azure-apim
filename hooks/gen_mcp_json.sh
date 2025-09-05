#!/usr/bin/env bash

# This script generates a .vscode/mcp.json configuration file using SPOTIFY_MCP_URL and SETLISTFM_MCP_URL environment variables.
# Usage: export SPOTIFY_MCP_URL=... SETLISTFM_MCP_URL=...; ./gen_mcp_json.sh

set -ex


# Get values from azd env get-value

SETLISTAPI_MCP_ENDPOINT=$(azd env get-value SETLISTAPI_MCP_ENDPOINT)
SETLISTAPI_SUBSCRIPTION_KEY=$(azd env get-value SETLISTAPI_SUBSCRIPTION_KEY)

if [[ -z "$SETLISTAPI_MCP_ENDPOINT" ]]; then
  echo "Error: SETLISTAPI_MCP_ENDPOINT is not set in azd environment." >&2
  exit 1
fi

cat > .vscode/mcp.json <<EOF
{

  "servers": {
    "setlistfm": {
      "type": "sse",
      "url": "${SETLISTAPI_MCP_ENDPOINT}",
      "headers": {"x-api-key": "${SETLISTAPI_SUBSCRIPTION_KEY}"},
    },
   
  }
}
EOF

echo ".vscode/mcp.json generated successfully."
