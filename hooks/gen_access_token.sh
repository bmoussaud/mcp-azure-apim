#!/bin/bash

set -e

# Generate Azure access token using azd auth and export it as environment variable
echo "Generating Azure access token using azd auth..."

# Get the access token using azd
access_token=$(azd auth token --output json | jq -r '.token')

if [[ -z "${access_token}" || "${access_token}" == "null" ]]; then
    echo "Failed to obtain access token from azd auth token" >&2
    exit 1
fi

# Export the access token as environment variable
export ACCESS_TOKEN="${access_token}"

# Add it to the .env file for the Python environment
azd env set ACCESS_TOKEN="${access_token}"

# Also add it to the shell .env file for debug.http (without quotes)
# Remove existing ACCESS_TOKEN line and add new one
sed -i '/^ACCESS_TOKEN=/d' src/shell/.env 2>/dev/null || true
echo "ACCESS_TOKEN=${access_token}" >> src/shell/.env

echo "Access token generated and exported successfully"
echo "Token expires on: $(azd auth token --output json | jq -r '.expiresOn')"