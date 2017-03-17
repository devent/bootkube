#!/bin/bash
set -euo pipefail

function configure_etcd() {

  echo "Creating etc.service for node"$1

  cat << EOF > /home/core/10-etcd-member.conf
[Service]
Environment="ETCD_IMAGE_TAG=$ETCD_VER"
Environment="ETCD_NAME=node$1"
Environment="ETCD_INITIAL_CLUSTER="$ETCD_CLUSTER"
Environment="ETCD_INITIAL_ADVERTISE_PEER_URLS=$ETCD_PROTO://${PRIPS[$1]}:2380"
Environment="ETCD_ADVERTISE_CLIENT_URLS=$ETCD_PROTO://${PRIPS[$1]}:2379"
Environment="ETCD_LISTEN_CLIENT_URLS=$ETCD_PROTO://0.0.0.0:2379"
Environment="ETCD_LISTEN_PEER_URLS=$ETCD_PROTO://0.0.0.0:2380"

EOF
}


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

if [ $# -ne 1 ]; then
  echo "Usage: ./`basename $0` CONFIGURATIONFILE"
  exit -1
fi

source $1

# We are on node1 and the first installation step takes place locally

# Check if k8s is already installed
if [ ! -f /home/core/.k8s_installed ]; then

  if [ $INSTALL_ETCD == "yes" ];
  then
    # Configure etcd on all nodes
    for node in 0 1 2;do
      echo "etcd for node "$node
      configure_etcd $node 
      scp /home/core/10-etcd-member.conf ${PRIPS[$node]}:/tmp/
      ssh ${PRIPS[$node]} 'sudo systemctl stop etcd-member; if [ -d /etc/systemd/system/etcd-member.service.d ];then sudo rm -rf /etc/systemd/system/etcd-member.service.d; fi; sudo mkdir /etc/systemd/system/etcd-member.service.d'
      ssh ${PRIPS[$node]} 'sudo rm -rf /var/lib/etcd/*; sudo mv /tmp/10-etcd-member.conf /etc/systemd/system/etcd-member.service.d/; sudo systemctl daemon-reload; sudo systemctl enable etcd-member'
      ./start_etcd_member_on_node.sh ${PRIPS[$node]} &
    done
    sleep 30
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
  
cat << EOF > /home/core/bin/environment.txt
  export PATH=$PATH:/home/core/bin
  export KUBECONFIG=/home/core/assets/auth/admin-kubeconfig
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
    --api-servers=$API_SERVERS \
    --etcd-servers=$ETCD_ENDPOINTS

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

  sleep 20

  while [ `/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/admin-kubeconfig get pods -n=kube-system | grep -v \^NAME | awk '{print $3}' | grep Running | wc -l` != 10 ]; do
    sleep 5
    echo "Container running: " `/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/admin-kubeconfig get pods -n=kube-system | grep -v \^NAME | awk '{print $3}' | grep Running | wc -l`
  done

  touch /home/core/.k8s_installed
  echo "Node1 installed. Moving ahead to node2"

fi

for node in `seq 2`; do

  if [ `ssh ${PRIPS[$node]} 'if [ ! -f /home/core/.k8s_installed ]; then echo "not_installed"; fi'` ]; then
    echo "Starting to install node"$node ${PRIPS[$node]}

    # node will be installed as second master
    # first we copy the necessary files to node2
    ssh ${PRIPS[$node]} 'if [ -d /home/core/assets ]; then rm -rf /home/core/assets; mkdir -p /home/core/assets/auth; fi' 
    ssh ${PRIPS[$node]} 'if [ -d /home/core/bin ]; then rm -rf /home/core/bin; fi'
    ssh ${PRIPS[$node]} 'if [ -d /etc/kubernetes ]; then sudo rm -r /etc/kubernetes/*;else sudo mkdir /etc/kubernetes; fi'

    scp -r /home/core/assets core@${PRIPS[$node]}:
    scp -r /home/core/bin core@${PRIPS[$node]}:
    
    #Adjust IP addresses in admin-kubeconfig 
    ssh ${PRIPS[$node]} "sed -i 's/server: https:\/\/${PRIPS[0]}:443/server: https:\/\/${PRIPS[$node]}:443/' /home/core/assets/auth/admin-kubeconfig"
    #ssh ${PRIPS[$node]} "sed -i 's/server: https:\/\/${PRIPS[0]}:443/server: https:\/\/${PRIPS[$node]}:443/' /home/core/assets/auth/bootstrap-kubeconfig"

    configure_kubelet ${PRIPS[$node]}
    scp /home/core/kubelet.service core@${PRIPS[$node]}:/home/core/assets/
    rm /home/core/kubelet.service
    ssh ${PRIPS[$node]} 'sudo cp /home/core/assets/auth/*kubeconfig /etc/kubernetes/'
    ssh ${PRIPS[$node]} 'sudo cp /home/core/assets/kubelet.service /etc/systemd/system/; sudo systemctl daemon-reload; sudo systemctl enable kubelet; sudo systemctl start kubelet'
    echo "Give kubelet some time ..."
    sleep 30
    ssh ${PRIPS[$node]} "sudo /usr/bin/rkt run --volume home,kind=host,source=/home/core --mount volume=home,target=/core --net=host $BOOTKUBE_REPO:$BOOTKUBE_VERSION --exec /bootkube -- start --asset-dir=/core/assets"

    while [ `/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/admin-kubeconfig get pods -n=kube-system | grep -v \^NAME | awk '{print $3}' | grep Running | wc -l` != $((10+$node*5)) ]; do
      sleep 5
      echo "Expected number of running pods: " $((10+$node*5))
      echo "Currently running: " `/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/admin-kubeconfig get pods -n=kube-system | grep -v \^NAME | awk '{print $3}' | grep Running | wc -l`
    done

  # Adjust IP address in /etc/kubernetes/kubeconfig and restart kubelet
  ssh ${PRIPS[$node]} "sudo sed -i 's/server: https:\/\/${PRIPS[0]}:443/server: https:\/\/${PRIPS[$node]}:443/' /etc/kubernetes/kubeconfig;sudo systemctl restart kubelet"

  else
    echo "Node"$node "already installed, please check "${PRIPS[$node]}
  fi

  ssh ${PRIPS[$node]} 'touch /home/core/.k8s_installed'
  echo "Node"$node "installed." 

done

# Scale controller-manager and scheduler to 3
echo "Scaling kube-controller-manager and kube-scheduler"
/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/admin-kubeconfig scale --current-replicas=2 --replicas=3 deployment/kube-controller-manager -n=kube-system
/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/admin-kubeconfig scale --current-replicas=2 --replicas=3 deployment/kube-scheduler -n=kube-system

# Install kubernetes dashboard
echo "Installing the dashboard"
/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/admin-kubeconfig create -f https://rawgit.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml

# Install heapster
echo "Installing heapster"
cd /tmp
if [ -d /tmp/heapster ]; then
 rm -rf /tmp/heapster
fi
git clone https://github.com/kubernetes/heapster.git
cd heapster
sed -i 's/# type: NodePort/type: NodePort/' deploy/kube-config/influxdb/grafana-service.yaml
/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/admin-kubeconfig create -f deploy/kube-config/influxdb/

echo "Installation done"
