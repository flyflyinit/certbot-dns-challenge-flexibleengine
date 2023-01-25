#!/bin/bash
# This script will be executed by certbot, when generating a a new certificate, to accept the DNS challenge on FlexibleEngine.

CREATE_DOMAIN="_acme-challenge.$CERTBOT_DOMAIN."

# Current working directory.
CURRENT_DIR=$(pwd);

# Path to environment variables.
source $CURRENT_DIR/environment-variables.sh

# Obtaining Token.
echo 'Authenticating and getting FE Token..'
TOKEN=$(curl -sSL -D - --request POST "https://iam.$REGION.$BASE_ENDPOINT/v3/auth/tokens?Content-Type=application/json"  \
--data-raw "{'auth': {'identity': {'methods': ['password'],'password': {'user': {'name': '$USER_NAME','password': '$USER_PASSWORD','domain': {'name': '$DOMAIN_NAME'}}}},'scope': {'project': {'id': '$PROJECT_ID'}}}}" | grep X-Subject-Token | sed s/"$TOKEN_HEADER_PREFIX"//);

# Adding a TXT record.
echo 'Adding TXT Record..'
CURL_CMD=$(echo curl --location --request POST "'"https://dns.$BASE_ENDPOINT/v2/zones/$DNS_ZONE_ID/recordsets?Content-Type=application/json"'" --header "'"X-Auth-Token: $TOKEN"'" --header \'Content-Type: application/json\' --data-raw "'"{\"name\": \"$CREATE_DOMAIN\",\"description\": \"This is an example record set.\",\"type\": \"TXT\",\"ttl\": 300,\"records\": ['"\"'$CERTBOT_VALIDATION'\""']}"'")
RECORD_ID=$( eval $CURL_CMD | python3 -c "import sys,json;print(json.load(sys.stdin)['id'])" )

# Save record_id for cleanup.
if [ ! -d /tmp/CERTBOT_$CERTBOT_DOMAIN ];then
        mkdir -m 0700 /tmp/CERTBOT_$CERTBOT_DOMAIN
fi
echo $RECORD_ID > /tmp/CERTBOT_$CERTBOT_DOMAIN/RECORD_ID

echo 'Sleeping for 10s, allowing TXT record to take effect..';
sleep 10 && echo "Done!";