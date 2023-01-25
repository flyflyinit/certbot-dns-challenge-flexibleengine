#!/bin/bash
# This script will create a new certifcate under /etc/letencypt/live/$DOMAIN/
# After creating the certificate, an authenticator.sh script  will be called to accept the DNS challenge on FlexibleEngine.  Next pushing the certificate to FlexibleEngine ELB. and assign it to the ELB HTTPS listener.

# an ELB instance, HTTPS listener, DNS A record, must be already provisioned.
# Please make sure to update ENV variables, as well as FlexibleEngine Authentication credentials on environment-variables.sh script.


# Current working directory.
CURRENT_DIR=$(pwd);

# Path to environment variables.
source $CURRENT_DIR/environment-variables.sh

# Generating Certificates for the first time.
echo 'Generating Certificate with Certbot..'
certbot certonly --manual --preferred-challenges=dns --manual-auth-hook $CURRENT_DIR/authenticator.sh  --manual-cleanup-hook $CURRENT_DIR/cleanup.sh -d $DNS_DOMAIN && echo "Done!";

# Obtaining Token.
echo 'Authenticating and getting FE Token..'
TOKEN=$(curl -sSL -D - --request POST "https://iam.$REGION.$BASE_ENDPOINT/v3/auth/tokens?Content-Type=application/json"  \
--data-raw "{'auth': {'identity': {'methods': ['password'],'password': {'user': {'name': '$USER_NAME','password': '$USER_PASSWORD','domain': {'name': '$DOMAIN_NAME'}}}},'scope': {'project': {'id': '$PROJECT_ID'}}}}" | grep X-Subject-Token | sed s/"$TOKEN_HEADER_PREFIX"//);

# Loading Certificate and Private key in env variables.
PRIVATE_KEY=$(echo \"`sed -E 's/$/\\\n/g' /etc/letsencrypt/live/$DNS_DOMAIN/privkey.pem`\" | sed -E 's/ //g' | sed -E 's/BEGINPRIVATEKEY/BEGIN PRIVATE KEY/g' | sed -E 's/ENDPRIVATEKEY-----\\n/END PRIVATE KEY-----/g')
CERTIFICATE=$(echo \"`sed -E 's/$/\\\n/g' /etc/letsencrypt/live/$DNS_DOMAIN/fullchain.pem`\" | sed -E 's/ //g' | sed -E 's/BEGINCERTIFICATE/BEGIN CERTIFICATE/g' | sed -E 's/ENDCERTIFICATE-----/END CERTIFICATE-----/g')

# Loading Certificate and Private key in ELB.
echo 'Putting Certificate in ELB..';
CURL_CMD=$(echo curl --location --request POST "'"https://elb.$REGION.$BASE_ENDPOINT/v3/$PROJECT_ID/elb/certificates?Content-Type=application/json"'" --header "'"X-Auth-Token: $TOKEN"'" --header "'"Content-Type: application/json"'" --data-raw "'"{\"certificate\" : {\"name\" :  \"$CERTIFICATE_NAME\",\"type\" : \"server\",\"private_key\" : $PRIVATE_KEY,\"certificate\" : $CERTIFICATE}}"'");

# Certificat ID will be in the returned json body .certificate.id
# If you don't have python3 installed, you can replace "python3" with the corresponding python version that you have.
CERTIFICATE_ID=$( eval $CURL_CMD | python3 -c "import sys,json;print(json.load(sys.stdin)['certificate']['id'])" )
echo "ELB Certificate ID: $CERTIFICATE_ID"

# Updating ELB HTTPS LISTENER to use the newly generated server certificate.
echo "Assigning Certificate to ELB Listener..";
CURL_CMD=$(echo curl --location --request PUT "'"https://elb.$REGION.$BASE_ENDPOINT/v3/$PROJECT_ID/elb/listeners/$LISTENER_ID?Content-Type=application/json"'" --header "'"X-Auth-Token: $TOKEN"'" --header "'"Content-Type: application/json"'" --data-raw "'"{\"listener\" : {\"default_tls_container_ref\" : \"$CERTIFICATE_ID\"}}"'");
eval $CURL_CMD && echo 'Done!';