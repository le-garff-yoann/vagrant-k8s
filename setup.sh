#!/bin/bash

SCRIPTDIR=$(dirname $(readlink -f "$0"))
CONFFILE="${SCRIPTDIR}/config.json"
STAGINGDIR=$(cat $CONFFILE | jq -cr .srvkube.host)

pushd $SCRIPTDIR

[[ -d $STAGINGDIR ]] || mkdir $STAGINGDIR

pushd $STAGINGDIR

virtual_domain=$(cat $CONFFILE | jq -cr .virtual.domain)

[[ -f ca-key.pem ]] || openssl genrsa -out ca-key.pem 2048
[[ -f ca.pem ]] || openssl req \
    -x509 -new -nodes \
    -key ca-key.pem \
    -days 10000 \
    -out ca.pem \
    -subj '/CN=kube-ca'

cat > openssl.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = kubernetes
DNS.3 = kubernetes.default
DNS.4 = kubernetes.default.svc
DNS.5 = kubernetes.default.svc.$(cat $CONFFILE | jq -cr .k8s.domain)
DNS.6 = k8s-api
DNS.7 = k8s-api.$virtual_domain
IP.1 = 127.0.0.1
IP.2 = $(cat $CONFFILE | jq -cr .k8s.vip)
IP.3 = $(cat $CONFFILE | jq -cr .k8s.default_route)
IP.4 = $(cat $CONFFILE | jq -cr .k8s.services.kubeapi.ip)
EOF

dns_c=7
ip_c=4

cat $CONFFILE | jq -cr '.virtual.nodes | to_entries[]' | while read l
do
    hostname=$(echo $l | jq -cr .key)
    ip=$(echo $l | jq -cr .value.ip)

    let dns_c++
    echo "DNS.${dns_c} = ${hostname}" >> openssl.cnf

    let dns_c++
    echo "DNS.${dns_c} = ${hostname}.${virtual_domain}" >> openssl.cnf

    let ip_c++
    echo "IP.${ip_c} = ${ip}" >> openssl.cnf

    cat > "worker-${hostname}-openssl.cnf" <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = ${hostname}
DNS.3 = ${hostname}.$virtual_domain
IP.1 = 127.0.0.1
IP.2 = ${ip}
EOF

    [[ -f "${hostname}-worker-key.pem" ]] || openssl genrsa -out "${hostname}-worker-key.pem" 2048
    [[ -f "${hostname}-worker.csr" ]] || openssl req -new \
        -key "${hostname}-worker-key.pem" \
        -out "${hostname}-worker.csr" \
        -subj "/O=system:nodes/CN=system:node:${hostname}" \
        -config "worker-${hostname}-openssl.cnf"
    [[ -f "${hostname}-worker.pem" ]] || openssl x509 -req -CAcreateserial \
        -in "${hostname}-worker.csr" \
        -CA ca.pem \
        -CAkey ca-key.pem \
        -out "${hostname}-worker.pem" \
        -days 7200 \
        -extensions v3_req \
        -extfile "worker-${hostname}-openssl.cnf"
done

[[ -f apiserver-key.pem ]] || openssl genrsa -out apiserver-key.pem 2048
[[ -f apiserver.csr ]] || openssl req -new \
    -key apiserver-key.pem \
    -out apiserver.csr \
    -subj '/CN=kube-apiserver' \
    -config openssl.cnf
[[ -f apiserver.pem ]] || openssl x509 -req \
    -in apiserver.csr \
    -CA ca.pem \
    -CAkey ca-key.pem \
    -CAcreateserial \
    -out apiserver.pem \
    -days 7200 \
    -extensions v3_req \
    -extfile openssl.cnf
[[ -f server.crt ]] || cp apiserver.pem server.crt
[[ -f server.key ]] || cp apiserver-key.pem server.key

[[ -f admin-key.pem ]] || openssl genrsa -out admin-key.pem 2048
[[ -f admin.csr ]] || openssl req -new \
    -key admin-key.pem \
    -out admin.csr \
    -subj '/O=system:masters/CN=kube-admin'
[[ -f admin.pem ]] || openssl x509 -req -CAcreateserial \
    -in admin.csr \
    -CA ca.pem \
    -CAkey ca-key.pem \
    -out admin.pem \
    -days 7200

for user in kube-proxy kube-controller-manager kube-scheduler
do
    [[ -f "${user}-key.pem" ]] || openssl genrsa -out "${user}-key.pem" 2048
    [[ -f "${user}.csr" ]] || openssl req -new \
        -key "${user}-key.pem" \
        -out "${user}.csr" \
        -subj "/CN=system:${user}"
    [[ -f "${user}.pem" ]] || openssl x509 -req -CAcreateserial \
        -in "${user}.csr" \
        -CA ca.pem \
        -CAkey ca-key.pem \
        -out "${user}.pem" \
        -days 7200
done

cat $CONFFILE | jq -cr '.virtual.nodes | to_entries[]' | while read l
do
    hostname=$(echo $l | jq -cr .key)

    cat > "openssl-${hostname}-etcd.cnf" <<EOF
    [req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = ${hostname}
DNS.3 = ${hostname}.${virtual_domain}
IP.1 = 127.0.0.1
IP.2 = $(echo $l | jq -cr .value.ip)
EOF

    [[ -f "${hostname}-etcd.key" ]] || \
        openssl genrsa -out "${hostname}-etcd.key" 2048

    [[ -f "${hostname}-etcd.csr" ]] || openssl req -new \
        -key "${hostname}-etcd.key" \
        -out "${hostname}-etcd.csr" \
        -subj "/CN=${hostname}" \
        -extensions v3_req \
        -config "openssl-${hostname}-etcd.cnf" \
        -sha256

    [[ -f "${hostname}-etcd.crt" ]] || openssl x509 -req -sha256 -CAcreateserial \
        -CA ca.pem \
        -CAkey ca-key.pem \
        -in "${hostname}-etcd.csr" \
        -out "${hostname}-etcd.crt" \
        -extensions v3_req \
        -extfile "openssl-${hostname}-etcd.cnf" \
        -days 7200
done

[[ -f traefik.key  ]] && [[ -f traefik.crt  ]] || openssl req \
    -x509 -nodes \
    -days 365 \
    -newkey rsa:2048 \
    -subj '/CN=*.virtual.local' \
    -keyout traefik.key \
    -out traefik.crt

popd

vagrant up && \
VAGRANT_K8S_PROVISIONING_STEP=base vagrant provision && \
VAGRANT_K8S_PROVISIONING_STEP=etcd vagrant provision && \
VAGRANT_K8S_PROVISIONING_STEP=flannel vagrant provision && \
VAGRANT_K8S_PROVISIONING_STEP=k8s vagrant provision && \
VAGRANT_K8S_PROVISIONING_STEP=k8s-addons vagrant provision

popd
