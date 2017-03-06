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
* mkdir -p /home/core/bin
* cp /tmp/test-etcd/etcdctl /home/core/bin
* /home/core/bin/etcdctl --version

Next, download the Kubernetes command utility into the same directory:

* curl https://storage.googleapis.com/kubernetes-release/release/v1.5.2/bin/linux/amd64/kubectl > /home/core/bin/kubectl
* chmod +x /home/core/bin/kubectl

Distribute your ssh key to all nodes, such that you can copy files from and to nodes.

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

ETCDCTL_API=3 /home/core/bin/etcdctl member list

The output should look like:

25184f9de106ed62, started, node2, http://10.104.100.245:2380, http://10.104.100.245:2379  
c1bc8c19990923cc, started, node1, http://10.104.100.236:2380, http://10.104.100.236:2379  
c6fb521b071b603c, started, node3, http://10.104.100.239:2380, http://10.104.100.239:2379  

## Install Kubernetes with the help of Bootkube

### Create assets for Kubernetes

In this scenario a self signed certificate authority, automatically created by Bootkube, will be used. The integration of an existing CA is not part of this document.

Log into prod00kube01 and execute the following steps and use Bootkube to create the required assets (kubeconfig, manifests and certificates) for the Kubernetes environment. If you want access the Kubernetes API server via a public IP address (37.x.x.x) you have to add the corresponding IP addresses here.

* /usr/bin/rkt run \  
        --volume home,kind=host,source=/home/core \  
        --mount volume=home,target=/core \  
        --trust-keys-from-https --net=host quay.io/coreos/bootkube:v0.3.8 \  
	--exec /bootkube -- render \  
	--asset-dir=/core/assets \  
	--api-servers=https://10.104.100.236:443,https://37.58.99.228:443,https://10.104.100.245:443,https://37.58.99.235:443,https://10.104.100.239:443,https://37.58.99.238:443 \  
	--etcd-servers=http://10.104.100.236:2379,http://10.104.100.245:2379,http://10.104.100.239:2379  
* chown -R core:core /home/core/assets
* mkdir -p /etc/kubernetes
* cp /home/core/assets/auth/bootstrap-kubeconfig /etc/kubernetes/

### Configure and start Kubelet service

* vim /etc/systemd/system/kubelet.service

[Service]  
Environment=KUBELET_ACI=quay.io/coreos/hyperkube  
Environment=KUBELET_VERSION=v1.5.3_coreos.0
Environment="RKT_OPTS=\  
--volume etc-resolv,kind=host,source=/etc/resolv.conf --mount volume=etc-resolv,target=/etc/resolv.conf \  
--volume var-lib-cni,kind=host,source=/var/lib/cni --mount volume=var-lib-cni,target=/var/lib/cni"  
EnvironmentFile=/etc/environment  
ExecStartPre=/bin/mkdir -p /etc/kubernetes/manifests  
ExecStartPre=/bin/mkdir -p /etc/kubernetes/cni/net.d  
ExecStartPre=/bin/mkdir -p /etc/kubernetes/checkpoint-secrets  
ExecStartPre=/bin/mkdir -p /srv/kubernetes/manifests  
ExecStartPre=/bin/mkdir -p /var/lib/cni  
ExecStart=/usr/lib/coreos/kubelet-wrapper \  
  --kubeconfig=/etc/kubernetes/kubeconfig \  
  --experimental-bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubeconfig \  
  --cert-dir=/etc/kubernetes/secrets \  
  --require-kubeconfig \  
  --cni-conf-dir=/etc/kubernetes/cni/net.d \  
  --network-plugin=cni \  
  --lock-file=/var/run/lock/kubelet.lock \  
  --exit-on-lock-contention \  
  --allow-privileged \  
  --hostname-override=$NODE_IP \  
  --node-labels=master=true \  
  --minimum-container-ttl-duration=3m0s \  
  --cluster_dns=10.3.0.10 \  
  --cluster_domain=cluster.local \  
  --config=/etc/kubernetes/manifests  

Restart=always  
RestartSec=5  

[Install]  
WantedBy=multi-user.target  

* systemctl daemon-reload
* systemctl enable kubelet
* systemctl start kubelet

### Start the Bootkube based provisioning of Kuberetes

* /usr/bin/rkt run \  
        --volume home,kind=host,source=/home/core \  
        --mount volume=home,target=/core \  
        --net=host quay.io/coreos/bootkube:v0.3.8 \  
	--exec /bootkube -- start --asset-dir=/core/assets  


After a few minutes Bootkube should report:  _All self-hosted control plane components successfully started_.
You can verify the installation with kubectl:  
/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/admin-kubeconfig get pods -n=kube-system

The output should be similar to this one:

NAME                                       READY     STATUS    RESTARTS   AGE  
checkpoint-installer-kwsj7                 1/1       Running   0          4m  
kube-apiserver-ww5bp                       1/1       Running   2          4m  
kube-controller-manager-2426318746-lg84k   1/1       Running   0          4m  
kube-controller-manager-2426318746-qk8wm   1/1       Running   0          4m  
kube-dns-4101612645-twgt4                  4/4       Running   0          4m  
kube-flannel-kb3k2                         2/2       Running   0          4m  
kube-proxy-k2562                           1/1       Running   0          4m  
kube-scheduler-2947727816-d7x93            1/1       Running   0          4m  
kube-scheduler-2947727816-hp104            1/1       Running   0          4m  
pod-checkpointer-10.104.100.236            1/1       Running   1          4m  

### Installation of prod00kube02 and prod00kube03

The assets created by Bootkube need to be copied to additional master nodes:

* scp -r /home/core/assets core@10.104.100.245:
* scp -r /home/core/assets core@10.104.100.239:

Perform the following steps on both nodes:  

* mkdir /etc/kubernetes
* cp /home/core/assets/auth/bootstrap-kubeconfig /etc/kubernetes
* vim /etc/systemd/system/kubelet.service (see above for the content)
* systemctl daemon-reload
* systemctl enable kubelet
* systemctl start kubelet
* /usr/bin/rkt run \  
        --volume home,kind=host,source=/home/core \  
        --mount volume=home,target=/core \  
        --net=host quay.io/coreos/bootkube:v0.3.8 \  
        --exec /bootkube -- start --asset-dir=/core/assets  




