#!/usr/bin/env bash

set -e

scriptdir=$(dirname $(readlink -f "$0"))

set -o allexport

. $scriptdir/.env
. $scriptdir/.defaults.env

set +o allexport

for ((i=1; i <= $VAGRANT_K8S_MASTERS_COUNT; i++))
do
    masters_addr+=$VAGRANT_K8S_MASTERS_NAME_PREFIX$i.$VAGRANT_K8S_VMS_DOMAIN:$VAGRANT_K8S_VMS_BASE_NETWORK.$(($VAGRANT_K8S_MASTERS_IP_START_AFTER+$i)),
done

for ((i=1; i <= $VAGRANT_K8S_NODES_COUNT; i++))
do
    nodes_addr+=$VAGRANT_K8S_NODES_NAME_PREFIX$i.$VAGRANT_K8S_VMS_DOMAIN:$VAGRANT_K8S_VMS_BASE_NETWORK.$(($VAGRANT_K8S_NODES_IP_START_AT+$i)),
done

_VAGRANT_K8S_MASTERS_VIP=$VAGRANT_K8S_MASTERS_VIP \
_VAGRANT_K8S_MASTERS_ADDR=$masters_addr \
_VAGRANT_K8S_NODES_ADDR=$nodes_addr \
    vagrant $@
