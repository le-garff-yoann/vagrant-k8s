# vagrant-k8s

Deploy a multi-master, multi-node Kubernetes cluster [preinstalled with some addons](provisioning/ansible/roles/k8s-addons) using Vagrant and Ansible.
**It's mostly meant for testing purposes.**

## Prerequisites

- `bash` and [Ansible](https://www.vagrantup.com/docs/provisioning/ansible.html#setup-requirements) (tested with version 2.9.6) installed on your host.
- `openssl` if you plan to use `tls-bootstraping.sh` to automatically generate the cluster CA and what comes out of it.

## Usage

### Configuration

```bash
cp .env.example .env
```

| ENV | Mandatory? | Default value | Description |
|-|-|-|-|
| `VAGRANT_K8S_MASTERS_COUNT` | ✓ | None | Number of masters. |
| `VAGRANT_K8S_MASTERS_CPUS` | ✓ | None | CPUs (for each master). |
| `VAGRANT_K8S_MASTERS_MEMORY` | ✓ | None | RAM (for each master). |
| `VAGRANT_K8S_NODES_COUNT` | ✓ | None | Number of nodes.  |
| `VAGRANT_K8S_NODES_CPUS` | ✓ | None | CPUs (for each node).  |
| `VAGRANT_K8S_NODES_MEMORY` | ✓ | None | RAM (for each node). |
| `VAGRANT_K8S_NODES_PORT_FORWARDING` | ☓ | None | [Port forwarding](https://www.vagrantup.com/docs/networking/forwarded_ports.html#defining-a-forwarded-port) rules (separated by `,`) to be applied for each node (separated by `:`). e.g. `8080=8080:8081=8081,8082=8082:8083=8083`. |

The `.defaults.env` file and the [Ansible roles](provisioning/ansible/roles) used for the provisioning of the instances defines/inject configuration too.

### TLS bootstraping

```bash
bash tls-bootstraping.sh
```

This script **will not generate files if they already exist** in the `$VAGRANT_K8S_CERTS_HOSTDIR` directory.


[That also means that you could provide your own certificates and keys](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet-tls-bootstrapping) by simply copying them into that directory. If you want to get an idea of ​​the name they should have just run `tls-bootstraping.sh` and look at the names of the files in the directory.

### Setup

```bash
bash vagrant.sh up
```

### Cleanup

```bash
bash vagrant.sh destroy
```
