#!/bin/bash
set -ex
CODE_JSON="/tmp/code.json"
TOKEN_JSON="/tmp/token.json"
# Replace these with your values
YOUR_CLIENT_ID="04b07795-8ddb-461a-bbee-02f9e1bf7b46"
YOUR_TENANT_ID="be38c437-5790-4e3a-bb56-4811371e35ea"

curl -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "client_id=${YOUR_CLIENT_ID}&scope=openid profile offline_access api://b66d5641-18b6-4332-966c-25d7ea2fc271/.default" -o ${CODE_JSON} "https://login.microsoftonline.com/${YOUR_TENANT_ID}/oauth2/v2.0/devicecode"
cat ${CODE_JSON} | jq .
DEVICE_CODE_FROM_PREVIOUS_RESPONSE=$(cat ${CODE_JSON} | jq '.device_code' | tr -d '"')
USER_CODE=$(cat ${CODE_JSON} | jq '.user_code' | tr -d '"')
VERIFICATION_URI=$(cat ${CODE_JSON} | jq '.verification_uri' | tr -d '"')
echo "Go to ${VERIFICATION_URI} and enter code ${USER_CODE}"
read -p "Press [Enter] key after you have authenticated..."
curl -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "grant_type=urn:ietf:params:oauth:grant-type:device_code&client_id=${YOUR_CLIENT_ID}&device_code=${DEVICE_CODE_FROM_PREVIOUS_RESPONSE}" -o ${TOKEN_JSON} "https://login.microsoftonline.com/${YOUR_TENANT_ID}/oauth2/v2.0/token" 

cat ${TOKEN_JSON} | jq .
ACCESS_TOKEN=$(cat ${TOKEN_JSON} | jq '.access_token' | tr -d '"')
echo "Access Token: ${ACCESS_TOKEN}"
# Now you can use the access token to call your API
curl -H "Authorization: Bearer ${ACCESS_TOKEN}" https://mcp-azure-apim-api-management-dev.azure-api.net/colors/colors/random | jq .
