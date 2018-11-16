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

* Without Traefik and Helm (better for [Gitlab integration!](https://docs.gitlab.com/ee/user/project/clusters/))

```bash
export VAGRANT_K8S_EXCLUDE_ADDONS='traefik helm'

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
  name: nginx-1
  labels:
    app: nginx-1
spec:
  ports:
    - port: 80
      protocol: TCP
  selector:
    app: nginx-1

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: nginx-1
spec:
  rules:
    - host: nginx-1.default.mydomain.io
      http:
        paths:
          - path: /
            backend:
              serviceName: nginx-1
              servicePort: 80

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-1
spec:
  selector:
    matchLabels:
      app: nginx-1
  replicas: 2
  template:
    metadata:
      labels:
        app: nginx-1
    spec:
      containers:
        - name: nginx-1
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
  --set serviceType=ClusterIP,ingress.enabled=true,ingress.hosts[0].name=wordpress-1.default.mydomain.io \
  --wait

exit

curl -Lk https://wordpress-1.default.mydomain.io # Wordpress up and running :)
```

## Cleanup

```bash
bash cleanup.sh
```
