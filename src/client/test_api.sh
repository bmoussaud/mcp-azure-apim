#!/bin/bash

source .env
echo $SETLISTAPI_ENDPOINT
echo $SETLISTAPI_SUBSCRIPTION_KEY
set -x
curl -H "x-api-key: $SETLISTAPI_SUBSCRIPTION_KEY" ${SETLISTAPI_ENDPOINT}/1.0/search/setlists?artistName=coldplay&p=1

