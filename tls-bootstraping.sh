#!/usr/bin/env bash

set -e

scriptdir=$(dirname $(readlink -f "$0"))

. $scriptdir/.env
. $scriptdir/.defaults.env

[[ -d $VAGRANT_K8S_CERTS_HOSTDIR ]] || mkdir $VAGRANT_K8S_CERTS_HOSTDIR

pushd $VAGRANT_K8S_CERTS_HOSTDIR

[[ -f ca.key ]] || openssl genrsa -out ca.key 2048
[[ -f ca.crt ]] || openssl req \
    -x509 -new -nodes \
    -key ca.key \
    -days 9999 \
    -out ca.crt \
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
DNS.5 = kubernetes.default.svc.$VAGRANT_K8S_K8S_DOMAIN
DNS.6 = $VAGRANT_K8S_MASTERS_VIP_NAME
DNS.7 = $VAGRANT_K8S_MASTERS_VIP_NAME.$VAGRANT_K8S_VMS_DOMAIN
IP.1 = 127.0.0.1
IP.2 = $VAGRANT_K8S_VMS_BASE_NETWORK.1
IP.3 = $VAGRANT_K8S_MASTERS_VIP
IP.4 = $VAGRANT_K8S_KUBEAPISERVER_CLUSTERIP
EOF

dns_c=7
ip_c=4

make_common_certs()
{
    let dns_c++
    echo "DNS.$dns_c = $1" >> openssl.cnf

    let dns_c++
    echo "DNS.$dns_c = $1.$VAGRANT_K8S_VMS_DOMAIN" >> openssl.cnf

    let ip_c++
    echo "IP.$ip_c = $2" >> openssl.cnf

    cat > "$1-kubelet-openssl.cnf" <<EOF
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
DNS.2 = $1
DNS.3 = $1.$VAGRANT_K8S_VMS_DOMAIN
IP.1 = 127.0.0.1
IP.2 = $2
EOF

    [[ -f "$1-kubelet.key" ]] || openssl genrsa -out "$1-kubelet.key" 2048
    [[ -f "$1-kubelet.csr" ]] || openssl req -new \
        -key "$1-kubelet.key" \
        -out "$1-kubelet.csr" \
        -subj "/O=system:nodes/CN=system:node:$1" \
        -config "$1-kubelet-openssl.cnf"
    [[ -f "$1-kubelet.crt" ]] || openssl x509 -req -CAcreateserial \
        -in "$1-kubelet.csr" \
        -CA ca.crt \
        -CAkey ca.key \
        -out "$1-kubelet.crt" \
        -days 9999 \
        -extensions v3_req \
        -extfile "$1-kubelet-openssl.cnf"

    cat > "openssl-$1-etcd.cnf" <<EOF
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
DNS.2 = $1
DNS.3 = $1.$VAGRANT_K8S_VMS_DOMAIN
IP.1 = 127.0.0.1
IP.2 = $2
EOF

    [[ -f "$1-etcd.key" ]] || \
        openssl genrsa -out "$1-etcd.key" 2048

    [[ -f "$1-etcd.csr" ]] || openssl req -new \
        -key "$1-etcd.key" \
        -out "$1-etcd.csr" \
        -subj "/CN=$1" \
        -extensions v3_req \
        -config "openssl-$1-etcd.cnf" \
        -sha256

    [[ -f "$1-etcd.crt" ]] || openssl x509 -req -sha256 -CAcreateserial \
        -CA ca.crt \
        -CAkey ca.key \
        -in "$1-etcd.csr" \
        -out "$1-etcd.crt" \
        -extensions v3_req \
        -extfile "openssl-$1-etcd.cnf" \
        -days 9999
}

for ((i=1; i <= $VAGRANT_K8S_NODES_COUNT; i++))
do
    make_common_certs $VAGRANT_K8S_NODES_NAME_PREFIX$i $VAGRANT_K8S_VMS_BASE_NETWORK.$(($VAGRANT_K8S_NODES_IP_START_AT+$i))
done

for ((i=1; i <= $VAGRANT_K8S_MASTERS_COUNT; i++))
do
    make_common_certs $VAGRANT_K8S_MASTERS_NAME_PREFIX$i $VAGRANT_K8S_VMS_BASE_NETWORK.$(($VAGRANT_K8S_MASTERS_IP_START_AFTER+$i))
done

[[ -f kube-apiserver.key ]] || openssl genrsa -out kube-apiserver.key 2048
[[ -f kube-apiserver.csr ]] || openssl req -new \
    -key kube-apiserver.key \
    -out kube-apiserver.csr \
    -subj '/CN=kube-apiserver' \
    -config openssl.cnf
[[ -f kube-apiserver.crt ]] || openssl x509 -req \
    -in kube-apiserver.csr \
    -CA ca.crt \
    -CAkey ca.key \
    -CAcreateserial \
    -out kube-apiserver.crt \
    -days 9999 \
    -extensions v3_req \
    -extfile openssl.cnf
[[ -f server.crt ]] || cp kube-apiserver.crt server.crt
[[ -f server.key ]] || cp kube-apiserver.key server.key

[[ -f admin.key ]] || openssl genrsa -out admin.key 2048
[[ -f admin.csr ]] || openssl req -new \
    -key admin.key \
    -out admin.csr \
    -subj '/O=system:masters/CN=kube-admin'
[[ -f admin.crt ]] || openssl x509 -req -CAcreateserial \
    -in admin.csr \
    -CA ca.crt \
    -CAkey ca.key \
    -out admin.crt \
    -days 9999

for user in kube-proxy kube-controller-manager kube-scheduler
do
    [[ -f "$user.key" ]] || openssl genrsa -out "$user.key" 2048
    [[ -f "$user.csr" ]] || openssl req -new \
        -key "$user.key" \
        -out "$user.csr" \
        -subj "/CN=system:$user"
    [[ -f "$user.crt" ]] || openssl x509 -req -CAcreateserial \
        -in "$user.csr" \
        -CA ca.crt \
        -CAkey ca.key \
        -out "$user.crt" \
        -days 9999
done

popd
