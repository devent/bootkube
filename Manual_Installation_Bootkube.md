# Manual installation of Kubernetes with Bootkube  

This document describes the steps to manually install Kubernetes with the help of [Bootkube](https://github.com/kubernetes-incubator/bootkube) on systems:

* prod00kube01.ams01.service.moovel.ibm.com - name node1 - IP 10.104.100.236 - public IP 37.58.99.228
* prod00kube02.ams01.service.moovel.ibm.com - name node2 - IP 10.104.100.245 - public IP 37.58.99.235
* prod00kube03.ams01.service.moovel.ibm.com - name node3 - IP 10.104.100.239 - public IP 37.58.99.238

On all three systems Container Linux is already installed. In addition, all three systems acts as:

* etcd server and
* Kubernetes master

The result is a high available Kubernetes cluster consisting of three nodes.

## Prerequisites

In the scope of this document etcd3 will be used. Etcd will run on each node as a rkt container. Unfortunately. the corresponding controll utility must be installed manually as it is not part of Container Linux yet. The instructions are given here [install_etcdctl](https://github.com/coreos/etcd/releases/):

* ETCD_VER=v3.1.1
* DOWNLOAD_URL=https://github.com/coreos/etcd/releases/download
* curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
* mkdir -p /tmp/test-etcd && tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/test-etcd --strip-components=1
* mkdir -p /root/bin
* cp /tmp/test-etcd/etcdctl /root/bin
* /root/bin/etcdctl --version


## Configure etcd on all three nodes

The following instructions need to be performed on all three nodes:

* mkdir -p /etc/systemd/system/etcd-member.service.d
* vim /etc/systemd/system/etcd-member.service.d/10-etcd-member.conf

[Service]  
Environment="ETCD_IMAGE_TAG=v3.1.1"  
Environment="ETCD_NAME=$NAME"  
Environment="ETCD_INITIAL_CLUSTER=node1=http://10.104.100.236:2380,node2=http://10.104.100.245:2380,node3=http://10.104.100.239:2380"  
Environment="ETCD_INITIAL_ADVERTISE_PEER_URLS=http://$NODE_IP:2380"  
Environment="ETCD_ADVERTISE_CLIENT_URLS=http://$NODE_IP:2379"  
Environment="ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379"  
Environment="ETCD_LISTEN_PEER_URLS=http://0.0.0.0:2380"  

Acitvate the corresponding systemd service:

* systemctl-daemon-reload
* systemctl enable etcd-member
* systemctl start etcd-member

With the following command you can verify if all node participate in the etcd cluster:

ETCDCTL_API=3 /root/bin/etcdctl member list

The output should look like:

25184f9de106ed62, started, node2, http://10.104.100.245:2380, http://10.104.100.245:2379  
c1bc8c19990923cc, started, node1, http://10.104.100.236:2380, http://10.104.100.236:2379  
c6fb521b071b603c, started, node3, http://10.104.100.239:2380, http://10.104.100.239:2379  


## Install Kubernetes with the help of Bootkube

In this scenario a self signed certificate authority, automatically created by Bootkube, will be used. The integration of an existing CA is not part of this document.

Log into prod00kube01 and execute the following steps and use Bootkube to create the required assets (kubeconfig, manifests and certificates) for the Kubernetes environment

* /usr/bin/rkt run \  
        --volume home,kind=host,source=/home/core \  
        --mount volume=home,target=/core \
        --trust-keys-from-https --net=host quay.io/coreos/bootkube:v0.3.7 \  
	--exec /bootkube -- render \  
	--asset-dir=/core/assets \  
	--api-servers=https://10.100.104.236:443,https://37.58.99.228:443,https://10.104.100.245:443,https://37.58.99.235:443,https://10.104.100.239:443,https://37.58.99.238:443 \  
	--etcd-servers=http://10.104.100.236:2379,http://10.104.100.245:2379,http://10.104.100.239:2379
