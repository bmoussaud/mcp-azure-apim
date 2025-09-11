#!/bin/bash
azd env get-values > .env
source .env
echo $SETLISTAPI_ENDPOINT
echo $SETLISTAPI_SUBSCRIPTION_KEY
set -x
curl -s  -H "Ocp-Apim-Subscription-Key: $SETLISTAPI_SUBSCRIPTION_KEY" ${SETLISTAPI_ENDPOINT}/1.0/search/setlists?artistName=the+weeknd&p=1 | jq

