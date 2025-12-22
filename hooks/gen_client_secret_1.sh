#!/bin/bash

set -e

OAUTH_APP_ID=$(azd env get-value OAUTH_APP_ID)
# Generate end date 21 days from now (UTC) for short-lived secret.
end_date=$(date -u -d '+21 days' '+%Y-%m-%dT%H:%M:%SZ')

client_secret=$(az ad app credential reset \
	--id "${OAUTH_APP_ID}" \
	--display-name "mcp-gen-$(date +%Y%m%d%H%M%S)" \
	--end-date "${end_date}" \
	--query password -o tsv)

if [[ -z "${client_secret}" || "${client_secret}" == "null" ]]; then
	echo "Failed to obtain client secret from az ad app credential reset" >&2
	exit 1
fi

azd env set OAUTH_CLIENT_SECRET="${client_secret}"

