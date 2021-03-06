#!/bin/bash
set -e

if [ -z "${STEPPATH}" ]; then
    echo "Missing STEPPATH environment variable."
    exit 1
fi

if [ -z "${DNS_NAME}" ]; then
    echo "Missing DNS_NAME environment variable."
    exit 1
fi

if [ -z "${PORT}" ]; then
    echo "Missing PORT environment variable."
    exit 1
fi

if [ -z "${CA_NAME}" ]; then
    echo "Missing CA_NAME environment variable."
    exit 1
fi

# add directories
mkdir -p $STEPPATH/certs
mkdir -p $STEPPATH/secrets
mkdir -p $STEPPATH/config
mkdir -p $STEPPATH/db

# CA stored in Azure Key Vault
if [ ! -z "$CA_ROOT_KEYVAULTID" ]; then

    # AAD Tenant ID specified, as opposed to MSI
    if [ ! -z "$AAD_TENANT_ID" ]; then
        if [ -z "$AAD_CLIENT_ID" ] | [ -z "$AAD_CLIENT_SECRET" ]; then
            echo "AAD Tenant ID specified but not client ID or client secret."
            exit 1
        fi

        curl -X POST -d "grant_type=client_credentials&client_id=${AAD_CLIENT_ID}&client_secret=${AAD_CLIENT_SECRET}&resource=https%3A%2F%2Fvault.azure.net" https://login.microsoftonline.com/${AAD_TENANT_ID}/oauth2/token | jq -r '.access_token' > /tmp/token
        TOKEN=$(cat /tmp/token)
        rm /tmp/token
        if [ -z "${TOKEN}" ]; then
            echo "Could not acquire access token."
            exit 1
        fi
    else
        curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -H 'Metadata: true' 2> /dev/null | jq -r '.access_token' > /tmp/token
        TOKEN=$(cat /tmp/token)
        rm /tmp/token
        if [ -z "${TOKEN}" ]; then
            echo "Could not acquire Managed Identity access token."
            exit 1
        fi
    fi

    # download certificate
    sid=`curl "${CA_ROOT_KEYVAULTID}?api-version=7.0" -H "Authorization: Bearer $TOKEN" 2> /dev/null | jq -r '.sid'`
    curl "${sid}?api-version=7.0" -H "Authorization: Bearer $TOKEN" 2> /dev/null | jq -r '.value' | base64 -d > /tmp/ca.pfx
fi

# support a CA specified directly
if [ ! -z "$CA_ROOT" ]; then
    echo "$CA_ROOT" | base64 -d > /tmp/ca.pfx
fi

# one or the other has to have worked
if [ ! -f /tmp/ca.pfx ]; then
    echo "Could not find CA_ROOT_KEYVAULTID or CA_ROOT."
    exit 1
fi

# check that we can successfully read CA bundle
if ! openssl pkcs12 -in /tmp/ca.pfx -info -nodes -passin pass: ; then
    echo "Cannot read /tmp/ca.pfx: invalid CA."
    exit 1
fi

# extract certificates
openssl pkcs12 -in /tmp/ca.pfx -cacerts -nodes -nokeys -passin pass: | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > $STEPPATH/certs/root_ca.crt
openssl pkcs12 -in /tmp/ca.pfx -clcerts -nodes -nokeys -passin pass: | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > $STEPPATH/certs/intermediate_ca.crt
openssl pkcs12 -in /tmp/ca.pfx -nocerts -nodes -passin pass: | sed -ne '/-BEGIN PRIVATE KEY-/,/-END PRIVATE KEY-/p' > $STEPPATH/secrets/intermediate_ca
rm -f /tmp/ca.pfx

# update config file
jq ".dnsNames = [\"${DNS_NAME}\"] |
    .address = \":${PORT}\" |
    .root = \"$(realpath $STEPPATH/certs/root_ca.crt)\" |
    .crt = \"$(realpath $STEPPATH/certs/intermediate_ca.crt)\" |
    .key = \"$(realpath $STEPPATH/secrets/intermediate_ca)\" |
    .logger.format = \"text\" |
    .db.type = \"badger\" |
    .db.dataSource = \"$STEPPATH/db\"
    " /step/ca.json > $STEPPATH/config/ca.json

# update client config file
jq ".\"ca-url\" = \"https://${DNS_NAME}\" |
    .fingerprint = \"$(step certificate fingerprint $STEPPATH/certs/root_ca.crt)\" |
    .root = \"$(realpath $STEPPATH/certs/root_ca.crt)\" |
    .\"redirect-url\" = \"\"
    " /step/defaults.json > $STEPPATH/config/defaults.json
