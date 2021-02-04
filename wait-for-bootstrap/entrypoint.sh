#!/bin/sh

# When the tezos-node boots for the first time and the bootstrap node is not up yet, it will never connect.
# So at first boot (when peers.json is empty) we wait for bootstrap node.
# This is probably a bug in tezos core, though.

if [ -s /var/tezos/node/peers.json ] && [ "$(jq length /var/tezos/node/peers.json)" -gt "0" ]; then
    printf "Node already has an internal list of peers, no need to wait for bootstrap \n"
    exit 0
fi

BOOTSTRAP_NODES=
for i in 0 1; do
    BOOTSTRAP_NODES="$BOOTSTRAP_NODES tezos-baking-node-$i.tezos-baking-node"
done

HOST=$(hostname -f)
for node in $BOOTSTRAP_NODES; do
    if [ "${HOST##$node}" != "$HOST" ]; then
	echo "I'm the one of the bootstrap nodes: do not wait for myself"
	exit 0
    fi
done

#
# wait for node to respond to rpc.  We still sleep between nc(1)'s because
# some errors are instant.
#
# We give the sleep some jitter because that's often helpful when firing
# up a lot of nodes.
#
# We also start off with a bit of a random sleep before we get going under
# the assumption that the bootstrap node will take some time to get going.
# Remember: the bootsrap node exit(3)ed above and so this slows down only
# those that are likely to need to wait a minute for it to start.

INTERVAL=1
randomsleep() {
    SLEEP=$(expr $(od -An -N1 -i /dev/random) % 15 + $INTERVAL)
    if [ $SLEEP -gt 30 ]; then
	SLEEP=30
    fi
    echo Sleeping for $SLEEP seconds.
    sleep $SLEEP
    if [ $INTERVAL -lt 20 ]; then
	INTERVAL=$(expr $INTERVAL + 2)
    fi
}

sleep 10
randomsleep
echo "waiting for bootstrap nodes to accept connections"

while :; do
    for node in $BOOTSTRAP_NODES; do
	if </dev/null nc -q 0 ${node} 8732; then
	    exit 0
	fi
    done
    randomsleep
done
