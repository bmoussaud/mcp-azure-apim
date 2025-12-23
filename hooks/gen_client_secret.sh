#!/bin/bash

set -ex
# get the property name from the command line arguments
APPID_PROPERTY_NAME="${1}"
CLIENT_SECRET_PROPERTY_NAME="${2}"
if [[ -z "${APPID_PROPERTY_NAME}" || -z "${CLIENT_SECRET_PROPERTY_NAME}" ]]; then
  echo "Usage: $0 <APPID_PROPERTY_NAME> <CLIENT_SECRET_PROPERTY_NAME>" >&2
  exit 1
fi


OAUTH_APP_ID=$(azd env get-value ${APPID_PROPERTY_NAME})
# Generate end date 21 days from now (UTC) for short-lived secret.
end_date=$(date -u -d '+21 days' '+%Y-%m-%dT%H:%M:%SZ')

client_secret=$(az ad app credential reset \
	--id "${OAUTH_APP_ID}" \
	--display-name "gen-$(date +%Y%m%d%H%M%S)" \
	--end-date "${end_date}" \
	--query password -o tsv)

if [[ -z "${client_secret}" || "${client_secret}" == "null" ]]; then
	echo "Failed to obtain client secret from az ad app credential reset" >&2
	exit 1
fi

azd env set ${CLIENT_SECRET_PROPERTY_NAME}="${client_secret}"

