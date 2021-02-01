import * as pulumi from "@pulumi/pulumi";
import * as eks from "@pulumi/eks";
import * as k8s from "@pulumi/kubernetes";
import * as awsx from "@pulumi/awsx";
import * as aws from "@pulumi/aws";

// Create a repository
const repo = new awsx.ecr.Repository("tezos-k8s");

import * as fs from 'fs';
import * as YAML from 'yaml'

const { readdirSync } = require('fs')

// Manual step: create a pulumi_values.yaml in the top level dir
// with mkchain command:
//   mkchain pulumi
//
const helm_values_file = fs.readFileSync('../pulumi_values.yaml', 'utf8')
const helm_values = YAML.parse(helm_values_file)

const nginx_ingress_helm_values_file = fs.readFileSync('nginx_ingress_values.yaml', 'utf8')
const nginx_ingress_helm_values = YAML.parse(nginx_ingress_helm_values_file)

let images : {};
images = helm_values['tezos_k8s_images'] || {};

let imagelist = ["baker_endorser", "chain_initiator", "config_generator",
	         "key_importer", "rpc_auth", "wait_for_bootstrap", "zerotier"]

for (let image of imagelist) {
    images[image] = repo.buildAndPushImage("../" + image.replace(/_/g, "-"))
}

helm_values["tezos_k8s_images"] = images;

const vpc = new awsx.ec2.Vpc("tezos-vpc", {});

// Create an EKS cluster.
const cluster = new eks.Cluster("tq-private-chain", {
    vpcId: vpc.id,
    subnetIds: vpc.publicSubnetIds,
})

// Deploy Tezos into our cluster.
const chain = new k8s.helm.v2.Chart("chain", {
    path: "../charts/tezos",
    values: helm_values,
}, { providers: { "kubernetes": cluster.provider } });

const rpc = new k8s.helm.v2.Chart("rpc-auth", {
    path: "../charts/rpc-auth",
    values: helm_values,
}, { providers: { "kubernetes": cluster.provider } });

// Manual step at this point:
// * create a certificate
// * put certificate arn in the nginx_ingress_values.yaml

const nginxIngress = new k8s.helm.v2.Chart("nginx-ingress", {
    chart: "ingress-nginx",
    fetchOpts: {
      repo: "https://kubernetes.github.io/ingress-nginx" },
    values: nginx_ingress_helm_values,
}, { providers: { "kubernetes": cluster.provider } });

// Manual steps after all is done:
// Enable proxy protocol v2 on the target groups:
//   https://github.com/kubernetes/ingress-nginx/issues/5051#issuecomment-685736696
// Create a A record in the dns domain for which a certificate was created.

// Export the cluster's kubeconfig.
export const kubeconfig = cluster.kubeconfig;
export const clusterName = cluster.eksCluster.name;
