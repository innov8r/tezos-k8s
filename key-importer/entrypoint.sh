#!/bin/sh

set -x

mkdir -p /var/tezos/client
chmod -R 777 /var/tezos/client

import_key() {
    echo $ACCOUNTS | \
    jq -r ".[] | select(.name == \"baker$1\") | .type, .name, .key" | (
	read keytype
	read name
	read key

	protocol=$(echo $CHAIN_PARAMS | jq -r '.protocol_hash')

	tezos-client -d /var/tezos/client --protocol ${protocol} \
	    import ${keytype} key ${name} unencrypted:${key} -f
    )
}

#
# For some reason, we all need to have baker0's key.  We can likely
# fix this in the future, I would imagine.

import_key 0

HOSTNAME=$(hostname)
MY_NODE=${HOSTNAME##tezos-baking-node-}
if [ "$MY_NODE" != "$HOSTNAME" ]; then
    import_key $MY_NODE
fi
