#!/bin/bash
set -euo pipefail

# Configuration
BOOTKUBE_REPO=${BOOTKUBE_REPO:-quay.io/coreos/bootkube}
BOOTKUBE_VERSION=${BOOTKUBE_VERSION:-v0.3.8}
ETCD_VER=v3.1.1
echo "ETCD_VER " $ETCD_VER
# Private IP addresses of API servers
declare -a PRIPS=("10.104.100.236" "10.104.100.245" "10.104.100.239")
# Public IP addresses of API Servers
declare -a PUIPS=("37.58.99.228" "37.58.99.235" "37.58.99.238")
# IP addresses of etcd nodes
declare -a ETCDIPS=("10.104.100.236" "10.104.100.245" "10.104.100.239")


function configure_kubelet() {

  echo "Creating kubelet.service for "$1

  cat << EOF > /home/core/kubelet.service
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
  --hostname-override=$1 \
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
}

# We are on node1 and the first installation step takes place locally

# Check if k8s is already installed
if [ ! -f /home/core/.k8s_installed ]; then

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
  
cat << EOF > /home/core/bin/environment.txt
  export PATH=$PATH:/home/core/bin
  export KUBECONFIG=/etc/kubernetes/admin-kubeconfig
  export ETCDCTL_API=3

EOF
  
  fi

  if [ -d "/home/core/assets" ]; then
    rm -rf /home/core/assets
  fi

  # Use Bootkube to create the relevant assets
  echo "Calling bootkube render to create K8s assets"

  sudo /usr/bin/rkt run \
    --volume home,kind=host,source=/home/core \
    --mount volume=home,target=/core \
    --trust-keys-from-https --net=host $BOOTKUBE_REPO:$BOOTKUBE_VERSION \
    --exec /bootkube -- render \
    --asset-dir=/core/assets \
    --api-servers=https://${PRIPS[0]}:443,https://${PUIPS[0]}:443,https://${PRIPS[1]}:443,https://${PUIPS[1]}:443,https://${PRIPS[2]}:443,https://${PUIPS[2]}:443 \
    --etcd-servers=http://${ETCDIPS[0]}:2379,http://${ETCDIPS[1]}:2379,http://${ETCDIPS[2]}:2379

  sudo chown -R core:core /home/core/assets

  if [ -d "/etc/kubernetes" ]; then
    sudo rm -rf /etc/kubernetes
  fi

  sudo mkdir -p /etc/kubernetes

  sudo cp /home/core/assets/auth/bootstrap-kubeconfig /etc/kubernetes/
  sudo cp /home/core/assets/auth/admin-kubeconfig /etc/kubernetes/

  # Configure and start kubelet.service
  echo "Configuring kubelet.service"
  configure_kubelet ${PRIPS[0]}

  sudo mv /home/core/kubelet.service /etc/systemd/system/
  sudo systemctl daemon-reload
  sudo systemctl enable kubelet
  sudo systemctl start kubelet

  # Start Bootkube based provisioning of Kubernetes
  echo "kubelet.service started. Now starting Bootkube"

  sudo /usr/bin/rkt run \
    --volume home,kind=host,source=/home/core \
    --mount volume=home,target=/core \
    --net=host $BOOTKUBE_REPO:$BOOTKUBE_VERSION \
    --exec /bootkube -- start --asset-dir=/core/assets

  while [ `/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/admin-kubeconfig get pods -n=kube-system | grep -v \^NAME | awk '{print $3}' | wc -l` != 10 ]; do
    sleep 5
    echo "Container running: " `/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/admin-kubeconfig get pods -n=kube-system | grep -v \^NAME | awk '{print $3}' | wc -l`
  done

  touch /home/core/.k8s_installed
  echo "Node1 installed. Moving ahead to node2"

fi

for node in `seq 1`; do

  if [ `ssh ${PRIPS[$node]} 'if [ ! -f /home/core/.k8s_installed ]; then echo "not_installed"; fi'` ]; then
    echo "Starting to install node"$node ${PRIPS[$node]}

    # node will be installed as second master
    # first we copy the necessary files to node2
    ssh ${PRIPS[$node]} 'if [ -d /home/core/assets ]; then rm -rf /home/core/assets; mkdir -p /home/core/assets/auth; fi' 
    ssh ${PRIPS[$node]} 'if [ -d /home/core/bin ]; then rm -rf /home/core/bin; fi'
    ssh ${PRIPS[$node]} 'if [ -d /etc/kubernetes ]; then sudo rm -rf /etc/kubernetes/*; fi'

    scp -r /home/core/assets core@${PRIPS[$node]}:
    scp -r /home/core/bin core@${PRIPS[$node]}:

    configure_kubelet ${PRIPS[$node]}
    scp /home/core/kubelet.service core@${PRIPS[$node]}:/home/core/assets/
    rm /home/core/kubelet.service
    ssh ${PRIPS[$node]} 'sudo cp /home/core/assets/auth/*kubeconfig /etc/kubernetes/'
    ssh ${PRIPS[$node]} 'sudo cp /home/core/assets/kubelet.service /etc/systemd/system/; sudo systemctl daemon-reload; sudo systemctl enable kubelet; sudo systemctl start kubelet'
    ssh ${PRIPS[$node]} "sudo /usr/bin/rkt run --volume home,kind=host,source=/home/core --mount volume=home,target=/core --net=host $BOOTKUBE_REPO:$BOOTKUBE_VERSION --exec /bootkube -- start --asset-dir=/core/assets"

    while [ `/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/admin-kubeconfig get pods -n=kube-system | grep -v \^NAME | awk '{print $3}' | wc -l` != $((10+$node*5)) ]; do
      sleep 5
      echo "Expected number of running pods: " $((10+$node*5))
      echo "Currently running: " `/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/admin-kubeconfig get pods -n=kube-system | grep -v \^NAME | awk '{print $3}' | wc -l`
    done

  else
    echo "Node"$node "already installed, please check "${PRIPS[$node]}
  fi

done
