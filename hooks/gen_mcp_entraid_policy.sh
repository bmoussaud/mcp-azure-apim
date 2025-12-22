#!/bin/bash
set -ex
OAUTH_TENANT_ID=$(azd env get-value OAUTH_TENANT_ID)
OAUTH_APP_ID=$(azd env get-value OAUTH_APP_ID)
SETLISTAPI_SUBSCRIPTION_KEY=$(azd env get-value SETLISTAPI_SUBSCRIPTION_KEY)

sed -e "s/OAUTH_TENANT_ID/${OAUTH_TENANT_ID}/g" \
    -e "s/OAUTH_APP_ID/${OAUTH_APP_ID}/g" \
    -e "s/SETLISTAPI_SUBSCRIPTION_KEY/${SETLISTAPI_SUBSCRIPTION_KEY}/g" \
    src/apim/setlistfm/mcp-policy-setlistfm-entra-id-template.xml > src/apim/setlistfm/mcp-policy-setlistfm-entra-id.xml
