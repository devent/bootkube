# Securing Etcd Cluster with Certificates

This document describes how to secure the Etcd cluster with SSL certificates.
Assuming we have the Etcd nodes in the cluster that are listed below.
We need to have one CA certificate for the cluster and for each node a
certificate signed by the CA. The node certificates must have the node IP 
addresses listed in the SANs section.

* prod00kube01.ams01.service.moovel.ibm.com - name node1 - IP 10.104.100.236 - public IP 37.58.99.228
* prod00kube02.ams01.service.moovel.ibm.com - name node2 - IP 10.104.100.245 - public IP 37.58.99.235
* prod00kube03.ams01.service.moovel.ibm.com - name node3 - IP 10.104.100.239 - public IP 37.58.99.238

FILE | DESCRIPTION | 
--- | --- |
ca_cert.pem | Cluster CA certificate. |
node_1_cert.pem | Node 1 certificate. FQDN: prod00kube01.ams01.service.moovel.ibm.com; SANs: IP:10.104.100.236,IP:37.58.99.228 |
node_1_key_insecure.pem | Node 1 private key without passphrase. |
node_2_cert.pem | Node 2 certificate. FQDN: prod00kube02.ams01.service.moovel.ibm.com; SANs: IP:10.104.100.245,IP:37.58.99.235 |
node_2_key_insecure.pem | Node 2 private key without passphrase. |
node_3_cert.pem | Node 3 certificate. FQDN: prod00kube03.ams01.service.moovel.ibm.com; SANs: IP:10.104.100.239,IP:37.58.99.238 |
node_3_key_insecure.pem | Node 3 private key without passphrase. |
client_cert.pem | Client certificate.|
client_key_insecure.pem | Client private key without passphrase. |

## Setup Server

We need to copy the certificates to the servers in the `/etc/ssl/certs/etcd/`
directory. As an alternative, the certificates can be generated directly on
the server, but each node certificate must be signed with the cluster CA.

We need to edit the `10-etcd-member.conf` on each server to set the certificates
and to switch to HTTPS.

`vi /etc/systemd/system/etcd-member.service.d/10-etcd-member.conf`

```
[Service]
...
Environment="ETCD_CERT_FILE=/etc/ssl/certs/etcd/node_1_cert.pem"
Environment="ETCD_KEY_FILE=/etc/ssl/certs/etcd/node_1_key_insecure.pem"
Environment="ETCD_PEER_CERT_FILE=/etc/ssl/certs/etcd/node_1_cert.pem"
Environment="ETCD_PEER_KEY_FILE=/etc/ssl/certs/etcd/node_1_key_insecure.pem"
Environment="ETCD_PEER_TRUSTED_CA_FILE=/etc/ssl/certs/etcd/ca_cert.pem"
Environment="ETCD_PEER_CLIENT_CERT_AUTH=true"
```

```
systemctl daemon-reload
systemctl enable etcd-member
systemctl start etcd-member
```

## Setup Etcdctl

If we have created client certificates that were signed by the cluster CA
we can use those to connect to the cluster. For convenience, we can create
a script that will export the needed settings.

`vi etcd-env.sh`

```
export ETCDCTL_API=3
export ETCDCTL_DIAL_TIMEOUT=3s
export ETCDCTL_ENDPOINTS=https://etcd-0.robobee.test:2379
export ETCDCTL_CACERT=/etc/ssl/certs/etcd/ca_cert.pem
export ETCDCTL_CERT=/etc/ssl/certs/etcd/client_cert.pem
export ETCDCTL_KEY=/etc/ssl/certs/etcd/client_key_insecure.pem
```

The `etcdctl` command should now be able to connect to the Etcd cluster.

```
etcdctl3 member list
```

## Setup Flanneld

The flannel service must also be configured to use the client certificate
to be able to connect to the secured Etcd cluster.

```
--etcd-keyfile="": SSL key file used to secure etcd communication.
--etcd-certfile="": SSL certification file used to secure etcd communication.
--etcd-cafile="": SSL Certificate Authority file used to secure etcd communication.
```

## Setup Kubernetes

The `kube-apiserver` must also be configured to use the client certificate
to be able to connect to the secured Etcd cluster.

The manifest file `kube-apiserver.yaml` must be amended with the
following options.

```
        - --etcd-servers=https://192.168.56.102:2379
        - --etcd-cafile=/etc/ssl/certs/etcd/ca_cert.pem
        - --etcd-certfile=/etc/ssl/certs/etcd/client_cert.pem
        - --etcd-keyfile=/etc/ssl/certs/etcd/client_key_insecure.pem
```
