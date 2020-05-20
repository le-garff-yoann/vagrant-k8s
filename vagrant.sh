#!/usr/bin/env bash

scriptdir=$(dirname $(readlink -f "$0"))
conffile="${scriptdir}/config.yml"

. $scriptdir/defaults.sh

for ((i = 1 ; i <= $(cat $conffile | yq -cr .virtual.nodes.count); i++))
do
    nodes_addr+=$node_name_prefix$i:$nodes_network.$(($nodes_ip_startafter+$i)),
done

_VAGRANT_K8S_NODES_VIP=$nodes_vip \
_VAGRANT_K8S_NODES_ADDR=$nodes_addr \
    vagrant $@
