#!/bin/bash
# This script will be executed by certbot, After accepting the DNS challenge on FlexibleEngine, to cleanup the environment.

# Current working directory
CURRENT_DIR=$(pwd);

# Path to environment variables.
source $CURRENT_DIR/environment-variables.sh

# Obtaining Token on a global project eu-west-0.
TOKEN=$(curl -sSL -D - --request POST "https://iam.$REGION.$BASE_ENDPOINT/v3/auth/tokens?Content-Type=application/json"  \
--data-raw "{'auth': {'identity': {'methods': ['password'],'password': {'user': {'name': '$USER_NAME','password': '$USER_PASSWORD','domain': {'name': '$DOMAIN_NAME'}}}},'scope': {'project': {'id': '$GLOBAL_PROJECT_ID'}}}}" | grep X-Subject-Token | sed s/"$TOKEN_HEADER_PREFIX"//);

# Delete tmp files
if [ -f /tmp/CERTBOT_$CERTBOT_DOMAIN/RECORD_ID ]; then
        RECORD_ID=$(cat /tmp/CERTBOT_$CERTBOT_DOMAIN/RECORD_ID)
        rm -f /tmp/CERTBOT_$CERTBOT_DOMAIN/RECORD_ID
fi

# Remove the challenge TXT record from the zone
echo "Removing TXT record.."
curl --location --request DELETE "https://dns.$BASE_ENDPOINT/v2/zones/$DNS_ZONE_ID/recordsets/$RECORD_ID" --header "X-Auth-Token: $TOKEN" 