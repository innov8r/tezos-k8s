# Tezos k8s Private Chain

This README will walk you through setting up a Tezos based private blockchain where you will spin up one bootstrap node as well as additional peer nodes if you'd like. Using `minikube`, these nodes will be running in a peer-to-peer network via a Zerotier VPN, inside of a Kubernetes cluster.

## Prerequisites

- python3
- [kubectl](https://kubernetes.io/docs/reference/kubectl/kubectl/)
- [minikube](https://minikube.sigs.k8s.io/docs/)
- [helm](https://helm.sh/)
- A [ZeroTier](https://www.zerotier.com/) network with api access token

## Installing prerequisites

This section varies depending on OS.

### Mac with homebrew

Make sure [homebrew](https://brew.sh/) is installed:

```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
```

Install prerequisites:

```shell
brew install python3 kubectl minikube helm
```

### Arch Linux

```shell
pacman -Syu && pacman -S python3 minikube kubectl kubectx helm
```

## Zerotier

Zerotier is a VPN service that the Tezos nodes in your cluster will use to communicate with each other.

Create a ZeroTier network:

- Go to https://my.zerotier.com
- Login with google credentials or create a new account
- Create a new API access token by clicking on the "Generate New
  Token" button. Save the generated access token. e.g. "yEflQt726fjXuSUyQ73WqXvAFoijXkLt"
- Go to https://my.zerotier.com/network
- Create a new network by clicking on the "Create a Network"
  button. Save the 16 character generated network
  id. e.g. "1c33c1ced02a5eee"

Set Zerotier environment variables in order to access these values with later commands:

```shell
ZT_TOKEN=yEflQt726fjXuSUyQ73WqXvAFoijXkLt
ZT_NET=1c33c1ced02a5eee
```

## Start Minikube

```shell
minikube start
```

If you don't have docker installed, or you do but don't want to use your local install, configure your shell environment to use minikube’s Docker daemon:

```shell
eval $(minikube docker-env)
```

## mkchain

mkchain is a python script that generates Helm values which Helm then uses to create your Tezos chain on k8s.

Follow _just_ the [Install mkchain](./mkchain/README.md#install-mkchain) step in `mkchain/README.md` under the Quickstart. See there for more info on how you can customize your chain.

Set as an environment variable the name you would like to give to your chain:

```shell
CHAIN_NAME=my-chain
```
NOTE: k8s will throw an error when deploying if your chain name format does not match certain requirements. From k8s: `DNS-1123 subdomain must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character (e.g. 'example.com', regex used for validation is '[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*')`

Set [unbuffered IO](https://docs.python.org/3.6/using/cmdline.html#envvar-PYTHONUNBUFFERED) for python:

```shell
PYTHONUNBUFFERED=x
```

## Start your chain

Run the following commands to create the Helm values, get the Helm chart repo, and install the Helm chart to start your chain.

```shell
mkchain $CHAIN_NAME --zerotier-network $ZT_NET --zerotier-token $ZT_TOKEN

helm repo add tqtezos https://tqtezos.github.io/tezos-helm-charts

helm install $CHAIN_NAME tqtezos/tezos-chain \
--values ./${CHAIN_NAME}_values.yaml \
--namespace tqtezos --create-namespace
```

Your kubernetes cluster will now be running a series of jobs to
perform the following tasks:

- get a zerotier ip
- generate a node identity
- generate a genesis block for your chain
- activate the protocol
- bake the first block
- start the bootstrap-node node and a baker to validate the chain

You can find your node in the tqtezos namespace using kubectl.

```shell
kubectl -n tqtezos get pods
```

You can view logs for your node using the following command:

```shell
kubectl -n tqtezos logs -l appType=tezos -c tezos-node -f
```

Congratulations! You now have an operational Tezos based permissioned
chain running one node.

## Adding nodes within the cluster

You can configure a self-contained testnet within your cluster with
a number of nodes of your choice by passing `--number-of-nodes N` to `mkchain`. Pass this along with your previously used flags (`--zerotier-network` and `--zerotier-token`). You can use this to scale up and down.

Or if you previously spun up the chain using `mkchain`, you may scale up/down your setup to an arbitrary number of nodes by adding or removing nodes in the `nodes` list in the values yaml file:

```
# <CURRENT WORKING DIRECTORY>/${CHAIN_NAME}_values.yaml
...
nodes:
  - bake_for: baker
  - {} # second non-baking node
  - {} # third non-baking node
...
```

To upgrade your Helm release run:

```shell
helm upgrade $CHAIN_NAME tqtezos/tezos-chain \
--values ./${CHAIN_NAME}_values.yaml \
--namespace tqtezos
```

The nodes will start up and establish peer-to-peer connections in a full mesh topology.

List all of your running nodes: `kubectl -n tqtezos get pods -l appType=tezos`

## Adding external nodes to the cluster

External nodes to your local cluster can be added to your network by sharing a yaml file
generated by the `mkchain` command.

The file is located at: `<CURRENT WORKING DIRECTORY>/${CHAIN_NAME}_invite_values.yaml`

Send this file to the recipients you want to invite.

### On the computer of the joining node

The member needs to:

1. Follow the [prerequisite installation instructions](#installing-prerequisites)
2. [Start minikube](#start-minikube)
3. [Install mkchain](./mkchain/README.md#install-mkchain)

Then run:

```shell
helm repo add tqtezos https://tqtezos.github.io/tezos-helm-charts

helm install $CHAIN_NAME tqtezos/tezos-chain \
--values <LOCATION OF ${CHAIN_NAME}_invite_values.yaml> \
--namespace tqtezos --create-namespace
```

At this point additional nodes will be added in a full mesh
topology.

Congratulations! You now have a multi-node Tezos based permissioned chain.

On each computer, run this command to check that the nodes have matching heads by comparing their hashes (it may take a minute for the nodes to sync up):

```shell
kubectl get pod -n tqtezos -l appType=tezos -o name |
while read line;
  do kubectl -n tqtezos exec $line -c tezos-node -- /usr/local/bin/tezos-client rpc get /chains/main/blocks/head/hash;
done
```

## RPC Authentication

You can optionally spin up an RPC authentication backend allowing trusted users to make RPC requests to your cluster.

Follow the steps [here](./rpc-auth/README.md).

# Notes

We recommend using a very nice GUI for your k8s Tezos chain infrastructure called [Lens](https://k8slens.dev/). This allows you to easily see all of the k8s resources that have been spun up as well as to view the logs for your Tezos nodes.
