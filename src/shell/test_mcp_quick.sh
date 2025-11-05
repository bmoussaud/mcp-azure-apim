#!/bin/bash
set -euo pipefail
set -x

# Quick MCP Server Test
# Simple curl-based test for MCP server endpoints

# Load environment
if command -v azd &> /dev/null; then
    azd env get-values > .env 2>/dev/null || true
fi
source .env 2>/dev/null || true

# Configuration
MCP_ENDPOINT="${SETLISTAPI_MCP_ENDPOINT:-}"
SUBSCRIPTION_KEY="${SETLISTAPI_SUBSCRIPTION_KEY:-}"

if [[ -z "$MCP_ENDPOINT" ]] || [[ -z "$SUBSCRIPTION_KEY" ]]; then
    echo "Error: Missing MCP_ENDPOINT or SUBSCRIPTION_KEY"
    echo "Set SETLISTAPI_MCP_ENDPOINT and SETLISTAPI_SUBSCRIPTION_KEY environment variables"
    exit 1
fi

echo "Testing MCP Server: $MCP_ENDPOINT"
echo "Using key: ${SUBSCRIPTION_KEY:0:8}..."

# Test 1: Initialize MCP
echo
echo "=== Test 1: MCP Initialize ==="
curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    -d '{
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {
                "roots": {"listChanged": true},
                "sampling": {}
            },
            "clientInfo": {
                "name": "curl-test",
                "version": "1.0.0"
            }
        }
    }' \
    "$MCP_ENDPOINT" 

# Test 2: List Tools
echo
echo "=== Test 2: List Tools ==="
curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    -d '{
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/list",
        "params": {}
    }' \
    "$MCP_ENDPOINT" | jq .

# Test 3: Search Artists
echo
echo "=== Test 3: Search Artists ==="
curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    -d '{
        "jsonrpc": "2.0",
        "id": 3,
        "method": "tools/call",
        "params": {
            "name": "searchForArtists",
            "arguments": {
                "artistName": "The Weeknd",
                "p": "1"
            }
        }
    }' \
    "$MCP_ENDPOINT" | jq .

# Test 4: Search Setlists
echo
echo "=== Test 4: Search Setlists ==="
curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    -d '{
        "jsonrpc": "2.0",
        "id": 4,
        "method": "tools/call",
        "params": {
            "name": "searchForSetlists",
            "arguments": {
                "artistName": "Arctic Monkeys",
                "year": "2024",
                "p": "1"
            }
        }
    }' \
    "$MCP_ENDPOINT" | jq .

echo
echo "=== Tests completed ==="