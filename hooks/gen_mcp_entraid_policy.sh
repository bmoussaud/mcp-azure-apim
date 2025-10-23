#!/bin/bash
set -ex
azd env get-values > .env
source .env

sed -e "s/OAUTH_TENANT_ID/${OAUTH_TENANT_ID}/g" \
    -e "s/OAUTH_APP_ID/${OAUTH_APP_ID}/g" \
    -e "s/SETLISTAPI_SUBSCRIPTION_KEY/${SETLISTAPI_SUBSCRIPTION_KEY}/g" \
    src/apim/setlistfm/mcp-policy-setlistfm-entra-id-template.xml > src/apim/setlistfm/mcp-policy-setlistfm-entra-id.xml
