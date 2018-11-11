#!/bin/bash

SCRIPTDIR=$(dirname $(readlink -f "$0"))
CONFFILE="${SCRIPTDIR}/config.json"

pushd $SCRIPTDIR

vagrant destroy -f
rm -Rf $(cat $CONFFILE | jq -cr .srvkube.host)

popd
