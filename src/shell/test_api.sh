#!/bin/bash
azd env get-values > .env
source .env
ARTIST="The Weeknd"
ARTIST_ENCODED=$(echo $ARTIST | sed 's/ /+/g')
echo $SETLISTAPI_ENDPOINT
echo $SETLISTAPI_SUBSCRIPTION_KEY
echo "Testing connection to $SETLISTAPI_ENDPOINT"
set -x
curl -s -H "Ocp-Apim-Subscription-Key: $SETLISTAPI_SUBSCRIPTION_KEY" "${SETLISTAPI_ENDPOINT}/1.0/search/setlists?artistName=${ARTIST_ENCODED}&p=1" | jq .setlist[0]
