#!/bin/bash

set -euo pipefail

# Load environment variables from .env file
if [[ -f .env ]]; then
    export $(grep -v '^#' .env | xargs)
fi

# Configuration variables
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
APIM_NAME="${APIM_NAME:-}"
API_ID="setlistfm"
API_RESOURCE_ID="${SETLISTAPI_API_ID:-}"
EXTERNAL_HOST="${SETLISTAPI_ENDPOINT:-}"
SUBSCRIPTION_KEY="${SETLISTAPI_SUBSCRIPTION_KEY:-}"
API_ENDPOINT="${SETLISTAPI_ENDPOINT:-}"
REQUEST_PARAMS="/1.0/search/artists?artistName=lady%20gaga&p=1&sort=sortName"

# Get access token (try dotenv first, then azd)
ACCESS_TOKEN="${ACCESS_TOKEN:-}"
if [[ -z "${ACCESS_TOKEN}" ]]; then
    echo "Getting access token using azd auth..."
    ACCESS_TOKEN=$(azd auth token --output json | jq -r '.token')
fi

if [[ -z "${ACCESS_TOKEN}" || "${ACCESS_TOKEN}" == "null" ]]; then
    echo "Failed to get access token" >&2
    exit 1
fi

echo "Using access token: ${ACCESS_TOKEN:0:20}..."

# Temporary files for responses
TEMP_DIR=$(mktemp -d)
DEBUG_CREDS_RESPONSE="${TEMP_DIR}/debug_creds.json"
API_RESPONSE="${TEMP_DIR}/api_response.json"
TRACE_RESPONSE="${TEMP_DIR}/trace_response.json"

# Cleanup function
cleanup() {
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

# Validate required variables
for var in SUBSCRIPTION_ID RESOURCE_GROUP APIM_NAME API_RESOURCE_ID SUBSCRIPTION_KEY API_ENDPOINT; do
    if [[ -z "${!var}" ]]; then
        echo "Error: Required environment variable ${var} is not set" >&2
        exit 1
    fi
done

echo "=== Step 1: Getting debug credentials ==="
curl -s -X POST \
    "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.ApiManagement/service/${APIM_NAME}/gateways/managed/listDebugCredentials?api-version=2023-05-01-preview" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"credentialsExpireAfter\": \"PT1H\",
        \"apiId\": \"${API_RESOURCE_ID}\",
        \"purposes\": [\"tracing\"]
    }" \
    -o "${DEBUG_CREDS_RESPONSE}"

# Check if the request was successful
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to get debug credentials" >&2
    exit 1
fi

# Extract debug token
DEBUG_TOKEN=$(jq -r '.token' "${DEBUG_CREDS_RESPONSE}")
if [[ -z "${DEBUG_TOKEN}" || "${DEBUG_TOKEN}" == "null" ]]; then
    echo "Error: Failed to extract debug token from response" >&2
    echo "Response:" >&2
    cat "${DEBUG_CREDS_RESPONSE}" >&2
    exit 1
fi

echo "Debug token obtained: ${DEBUG_TOKEN:0:20}..."

echo "=== Step 2: Making API call with debug headers ==="
API_HEADERS_FILE="${TEMP_DIR}/api_headers.txt"

curl -s -X GET \
    "${API_ENDPOINT}${REQUEST_PARAMS}" \
    -H "Apim-Debug-Authorization: ${DEBUG_TOKEN}" \
    -H "Ocp-Apim-Subscription-Key: ${SUBSCRIPTION_KEY}" \
    -H "Content-Type: application/json" \
    -D "${API_HEADERS_FILE}" \
    -o "${API_RESPONSE}"

if [[ $? -ne 0 ]]; then
    echo "Error: API call failed" >&2
    exit 1
fi

# Extract trace ID from response headers
TRACE_ID=$(grep -i "apim-trace-id" "${API_HEADERS_FILE}" | cut -d: -f2 | tr -d ' \r\n')
if [[ -z "${TRACE_ID}" ]]; then
    echo "Warning: No trace ID found in response headers"
    echo "Headers:" >&2
    cat "${API_HEADERS_FILE}" >&2
else
    echo "Trace ID obtained: ${TRACE_ID}"
fi

echo "API Response:"
cat "${API_RESPONSE}"
echo ""

if [[ -n "${TRACE_ID}" ]]; then
    echo "=== Step 3: Getting trace information ==="
    curl -s -X POST \
        "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.ApiManagement/service/${APIM_NAME}/gateways/managed/listTrace?api-version=2024-06-01-preview" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"traceId\": \"${TRACE_ID}\"
        }" \
        -o "${TRACE_RESPONSE}"

    if [[ $? -eq 0 ]]; then
        echo "Trace Response:"
        cat "${TRACE_RESPONSE}" | jq '.' 2>/dev/null || cat "${TRACE_RESPONSE}"
    else
        echo "Error: Failed to get trace information" >&2
    fi
fi

echo ""
echo "=== Debug Summary ==="
echo "Subscription ID: ${SUBSCRIPTION_ID}"
echo "Resource Group: ${RESOURCE_GROUP}"
echo "APIM Name: ${APIM_NAME}"
echo "API Resource ID: ${API_RESOURCE_ID}"
echo "API Endpoint: ${API_ENDPOINT}${REQUEST_PARAMS}"
echo "Debug Token: ${DEBUG_TOKEN:0:20}..."
[[ -n "${TRACE_ID}" ]] && echo "Trace ID: ${TRACE_ID}"
echo "Response files saved in: ${TEMP_DIR}"
echo "Debug completed successfully!"