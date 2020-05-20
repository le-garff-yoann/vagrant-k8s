#!/usr/bin/env bash

scriptdir=$(dirname $(readlink -f "$0"))
conffile="${scriptdir}/config.yml"

bash $scriptdir/vagrant.sh destroy -f
RC=$?

rm -Rf $(cat $conffile | yq -cr .srvkube.host)

popd

exit $RC
