#!/bin/bash
set -euo pipefail

# Configuration
BOOTKUBE_REPO=${BOOTKUBE_REPO:-quay.io/coreos/bootkube}
BOOTKUBE_VERSION=${BOOTKUBE_VERSION:-v0.3.8}

# Check if k8s is already installed
if [ ! -f /home/core/.k8s_installed ]; then
  echo "K8s already installed "
  echo "Stopping"
  exit -1
fi

# Prerequisites - Installation of etcdctl and kubectl in /home/core/bin
echo "Checking for prerequisites ..."

if [ ! -d "/home/core/bin" ]; then
  mkdir -p /home/core/bin

  DOWNLOAD_URL=https://github.com/coreos/etcd/releases/download
  curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
  mkdir -p /tmp/test-etcd && tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/test-etcd --strip-components=1
  cp /tmp/test-etcd/etcdctl /home/core/bin

  curl https://storage.googleapis.com/kubernetes-release/release/v1.5.2/bin/linux/amd64/kubectl > /home/core/bin/kubectl
  chmod +x /home/core/bin/kubectl
fi

if [ -d "/etc/kubernetes" ]; then
  rm -rf /etc/kubernetes
fi

mkdir -p /etc/kubernetes

cp /home/core/assets/auth/bootstrap-kubeconfig /etc/kubernetes/
cp /home/core/assets/auth/admin-kubeconfig /etc/kubernetes/

# Configure and start kubelet.service
echo "Configuring kubelet.service"

cat << EOF > /etc/systemd/system/kubelet.service
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
  --hostname-override=$private_ipv4 \
  --node-labels=master=true \
  --minimum-container-ttl-duration=3m0s \
  --cluster_dns=10.3.0.10 \
  --cluster_domain=cluster.local \
  --config=/etc/kubernetes/manifests

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target

EOF

systemctl daemon-reload
systemctl enable kubelet
systemctl start kubelet

# Start Bootkube based provisioning of Kubernetes
echo "kubelet.service started. Now starting Bootkube"

/usr/bin/rkt run \
  --volume home,kind=host,source=/home/core \
  --mount volume=home,target=/core \
  --net=host $BOOTKUBE_REPO:$BOOTKUBE_VERSION \
  --exec /bootkube -- start --asset-dir=/core/assets

touch /home/core/.k8s_installed

exit
