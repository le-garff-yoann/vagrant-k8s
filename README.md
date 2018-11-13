# vagrant-k8s

This is a template for deploying a k8s cluster.

## Others prerequisites

* Ports `80` and `443` availables on your host.
* `bash`, `jq` and `openssl` installed on your host.

## Setup

* With self signed certificates for `Ingress`

```bash
bash setup.sh
```

* With [ACME (Let's Encrypt)](https://docs.traefik.io/configuration/acme) for `Ingress`

```bash
# export \
#   VAGRANT_K8S_ACME_CASERVER=https://acme-staging-v02.api.letsencrypt.org/directory

export \
  VAGRANT_K8S_ACME_EMAIL=used4registration@gmail.com

bash setup.sh
```

## Usage

### e.g. nginx `Deployment`

```bash
vagrant ssh k8s01

sudo kubectl apply -f - <<EOF
---
apiVersion: v1
kind: Service
metadata:
  name: my-nginx
  labels:
    app: my-nginx
spec:
  ports:
    - port: 80
      protocol: TCP
  selector:
    app: my-nginx

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: my-nginx
spec:
  rules:
    - host: my-nginx.default.mydomain.io
      http:
        paths:
          - path: /
            backend:
              serviceName: my-nginx
              servicePort: 80

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-nginx
spec:
  selector:
    matchLabels:
      app: my-nginx
  replicas: 2
  template:
    metadata:
      labels:
        app: my-nginx
    spec:
      containers:
        - name: my-nginx
          image: nginx
          ports:
            - containerPort: 80
EOF

exit

curl -Lk https://nginx-1.default.mydomain.io # Welcome to nginx! 
```

### eg. Wordpress with Helm

```bash
vagrant ssh k8s01

sudo helm install stable/wordpress \
  --name wordpress-1 \
  --set persistence.enabled=false,mariadb.master.persistence.enabled=false,serviceType=ClusterIP,ingress.enabled=true,ingress.hosts[0].name=my-wordpress.default.mydomain.io \
  --wait

exit

curl -Lk https://wordpress-1.default.mydomain.io # Wordpress up and running :)
```

## Cleanup

```bash
bash cleanup.sh
```
