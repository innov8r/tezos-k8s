#!/bin/bash

while test $# -gt 0; do
  case "$1" in
  -h | --help)
    echo "options:"
    echo "-h, --help                show brief help"
    echo "--cluster-address         specify ip or url for requesting nonce"
    echo "--chain-id                specify chain id of permission chain"
    echo "--tz-alias                specify tz alias of your key"
    exit 0
    ;;
  --cluster-address)
    shift
    if test $# -gt 0; then
      export CLUSTER_ADDRESS=$1
    else
      echo "no address specified"
      exit 1
    fi
    shift
    ;;
  --chain-id)
    shift
    if test $# -gt 0; then
      export CHAIN_ID=$1
    else
      echo "no chain id specified"
      exit 1
    fi
    shift
    ;;
  --tz-alias)
    shift
    if test $# -gt 0; then
      export TZ_ALIAS=$1
    else
      echo "no tz alias specified"
      exit 1
    fi
    shift
    ;;
  *)
    break
    ;;
  esac
done

if [ -z "$CLUSTER_ADDRESS" ]; then
  echo "--cluster-address flag is required"
  exit 1
elif [ -z "$CHAIN_ID" ]; then
  echo "--chain-id flag is required"
  exit 1
elif [ -z "$TZ_ALIAS" ]; then
  echo "--tz-alias flag is required"
  exit 1
fi

if ! tezos-client show address $TZ_ALIAS >/dev/null 2>&1; then
  echo "no public key hash alias named $TZ_ALIAS"
  exit 1
fi

get_response_body() {
  echo $1 | sed -e 's/ HTTPSTATUS\:.*//g'
}
get_response_status() {
  printf '%q' $1 | sed -e 's/.*HTTPSTATUS://'
}

nonce_res=$(curl -s -X GET http://localhost:8080/vending-machine/$CHAIN_ID -w " HTTPSTATUS:%{http_code}")
# nonce_res=$(curl -s -X GET http://$CLUSTER_ADDRESS/vending-machine/$CHAIN_ID -w " HTTPSTATUS:%{http_code}")
NONCE=$(get_response_body "$nonce_res")
nonce_res_status=$(get_response_status "$nonce_res")

if [ "$nonce_res_status" != "200" ]; then
  echo "Failed to get nonce. [HTTP status: $nonce_res_status]"
  echo "$nonce_res"
  exit 1
fi

echo NONCE: "$NONCE"

SIGNATURE=$(tezos-client -p PsCARTHAGazK sign bytes 0x05${NONCE} for ${TZ_ALIAS} | cut -f 2 -d " ")
PUBLIC_KEY=$(tezos-client show address ${TZ_ALIAS} 2>/dev/null | grep "Public Key: " | awk '{print $3}')

echo SIGNATURE: "$SIGNATURE"
echo PUBLIC_KEY: "$PUBLIC_KEY"

secret_url_res=$(curl -s -X GET -d "nonce=${NONCE}" -d "signature=${SIGNATURE}" -d "public_key=${PUBLIC_KEY}" http://localhost:8080/vending-machine -w " HTTPSTATUS:%{http_code}")
# https:/$CLUSTER_ADDRESS/vending-machine)
SECRET_URL=$(get_response_body "$secret_url_res")
secret_url_status=$(get_response_status "$secret_url_res")

echo SECRET_URL_STATUS: "$secret_url_status"

if [ "$secret_url_status" != "200" ]; then
  echo "Failed to get secret url. [HTTP status: $secret_url_status]"
  echo "$secret_url_res"
  exit 1
fi

echo SECRET_URL: "$SECRET_URL"

