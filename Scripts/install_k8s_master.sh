#!/bin/bash
set -euo pipefail

#
# Changes the work directory to the script base directory.
#
function changeWorkDir() {
  DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  cd "$DIR"
}

function configure_kubelet() {

  echo "Creating kubelet.service for "$1

  cat << EOF > /home/core/kubelet.service
[Service]
Environment=KUBELET_IMAGE_URL=$KUBELET_IMAGE_URL
Environment=KUBELET_IMAGE_TAG=$KUBELET_IMAGE_TAG
Environment="RKT_RUN_ARGS=\
--uuid-file-save=/var/run/kubelet-pod.uuid \
--volume var-log,kind=host,source=/var/log --mount volume=var-log,target=/var/log \
--volume etc-resolv,kind=host,source=/etc/resolv.conf --mount volume=etc-resolv,target=/etc/resolv.conf \
--volume var-lib-cni,kind=host,source=/var/lib/cni --mount volume=var-lib-cni,target=/var/lib/cni"
EnvironmentFile=/etc/environment
ExecStartPre=/bin/mkdir -p /etc/kubernetes/manifests
ExecStartPre=/bin/mkdir -p /etc/kubernetes/cni/net.d
ExecStartPre=/bin/mkdir -p /etc/kubernetes/checkpoint-secrets
ExecStartPre=/bin/mkdir -p /srv/kubernetes/manifests
ExecStartPre=/bin/mkdir -p /var/log/containers
ExecStartPre=/bin/mkdir -p /var/lib/cni
ExecStartPre=-/usr/bin/rkt rm --uuid-file=/var/run/kubelet-pod.uuid
ExecStart=/usr/lib/coreos/kubelet-wrapper \
  --kubeconfig=/etc/kubernetes/kubeconfig \
  --require-kubeconfig \
  --client-ca-file=/etc/kubernetes/ca.crt \
  --anonymous-auth=false \
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

ExecStop=-/usr/bin/rkt stop --uuid-file=/var/run/kubelet-pod.uuid
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}


if [ $# -ne 1 ]; then
  echo "Usage: ./install_k8s_master.sh CONFIGURATIONFILE"
  exit -1
fi

source $1

changeWorkDir

# We are on node1 and the first installation step takes place locally

# Check if k8s is already installed
if [ ! -f /home/core/.k8s_installed ]; then

  # Prerequisites - Installation of etcdctl and kubectl in /home/core/bin
  echo "Checking for prerequisites ..."

  if [ ! -d "/home/core/bin" ]; then
    mkdir -p /home/core/bin
  fi

  curl https://storage.googleapis.com/kubernetes-release/release/v1.5.4/bin/linux/amd64/kubectl > /home/core/bin/kubectl
  chmod +x /home/core/bin/kubectl
  
cat << EOF > /home/core/bin/environment.txt
  export PATH=$PATH:/home/core/bin
  export KUBECONFIG=/home/core/assets/auth/kubeconfig
  export ETCDCTL_API=3

EOF
  
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

  sudo rm -rf /etc/kubernetes; true
  sudo mkdir -p /etc/kubernetes

  #sudo cp /home/core/assets/auth/bootstrap-kubeconfig /etc/kubernetes/
  #sudo cp /home/core/assets/auth/admin-kubeconfig /etc/kubernetes/
  sudo cp /home/core/assets/auth/kubeconfig /etc/kubernetes/
  sudo cp /home/core/assets/tls/ca.crt /etc/kubernetes/ca.crt

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
    --volume manifests,kind=host,source=/etc/kubernetes/manifests \
    --mount volume=manifests,target=/etc/kubernetes/manifests \
    --net=host ${BOOTKUBE_REPO}:${BOOTKUBE_VERSION} \
    --exec /bootkube -- start --asset-dir=/core/assets 

  sleep 20

  while [ `/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/kubeconfig get pods -n=kube-system | grep -v \^NAME | awk '{print $3}' | grep Running | wc -l` != 10 ]; do
    sleep 5
    echo "Container running: " `/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/kubeconfig get pods -n=kube-system | grep -v \^NAME | awk '{print $3}' | grep Running | wc -l`
  done

  touch /home/core/.k8s_installed
  echo "Node1 installed. Moving ahead to node2"

fi

if [ ${#PRIPS[@]} -ne 1 ];then

  for node in `seq 2`; do

    is_installed=$(ssh ${PRIPS[$node]} 'if [ ! -f /home/core/.k8s_installed ]; then echo "not_installed"; else echo "installed"; fi')
    ret=$?
    if [[ $ret == 255 ]]; then
      echo "Error $ret, exit."
      exit $ret
    fi
    
    if [[ "$is_installed" != "installed" ]]; then
      echo "Starting to install node"$node ${PRIPS[$node]}

      # node will be installed as second master
      # first we copy the necessary files to node2
      ssh ${PRIPS[$node]} 'if [ -d /home/core/assets ]; then \
      rm -rf /home/core/assets; \
      mkdir -p /home/core/assets/auth; \
      fi' 
      ssh ${PRIPS[$node]} 'if [ -d /home/core/bin ]; then \
      rm -rf /home/core/bin; \
      fi'
      ssh ${PRIPS[$node]} 'if [ -d /etc/kubernetes ]; then \
      sudo rm -r /etc/kubernetes/*; \
      else sudo mkdir /etc/kubernetes; \
      fi'

      scp -r /home/core/assets core@${PRIPS[$node]}:
      scp -r /home/core/bin core@${PRIPS[$node]}:
    
      #Adjust IP addresses in kubeconfig 
      ssh ${PRIPS[$node]} "sed -i 's/server: https:\/\/${PRIPS[0]}:443/server: https:\/\/${PRIPS[$node]}:443/' /home/core/assets/auth/kubeconfig"
      #ssh ${PRIPS[$node]} "sed -i 's/server: https:\/\/${PRIPS[0]}:443/server: https:\/\/${PRIPS[$node]}:443/' /home/core/assets/auth/bootstrap-kubeconfig"

      configure_kubelet ${PRIPS[$node]}
      scp /home/core/kubelet.service core@${PRIPS[$node]}:/home/core/assets/
      rm /home/core/kubelet.service
      ssh ${PRIPS[$node]} 'sudo cp /home/core/assets/auth/*kubeconfig /etc/kubernetes/;sudo cp /home/core/assets/tls/ca.crt /etc/kubernetes/'
      ssh ${PRIPS[$node]} 'sudo cp /home/core/assets/kubelet.service /etc/systemd/system/; sudo systemctl daemon-reload; sudo systemctl enable kubelet; sudo systemctl start kubelet'
      echo "Give kubelet some time ..."
      sleep 30
      ssh ${PRIPS[$node]} "sudo /usr/bin/rkt run --volume home,kind=host,source=/home/core --mount volume=home,target=/core --net=host $BOOTKUBE_REPO:$BOOTKUBE_VERSION --exec /bootkube -- start --asset-dir=/core/assets"

      while [ `/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/kubeconfig get pods -n=kube-system | grep -v \^NAME | awk '{print $3}' | grep Running | wc -l` != $((10+$node*5)) ]; do
        sleep 5
        echo "Expected number of running pods: " $((10+$node*5))
        echo "Currently running: " `/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/kubeconfig get pods -n=kube-system | grep -v \^NAME | awk '{print $3}' | grep Running | wc -l`
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
  /home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/kubeconfig scale --current-replicas=2 --replicas=3 deployment/kube-controller-manager -n=kube-system
  /home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/kubeconfig scale --current-replicas=2 --replicas=3 deployment/kube-scheduler -n=kube-system

fi

# Install kubernetes dashboard
echo "Installing the dashboard"
/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/kubeconfig create -f https://rawgit.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml

# Install heapster
echo "Installing heapster"
cd /tmp
if [ -d /tmp/heapster ]; then
 rm -rf /tmp/heapster
fi
git clone https://github.com/kubernetes/heapster.git
cd heapster
sed -i 's/# type: NodePort/type: NodePort/' deploy/kube-config/influxdb/grafana-service.yaml
/home/core/bin/kubectl --kubeconfig=/home/core/assets/auth/kubeconfig create -f deploy/kube-config/influxdb/

echo "Installation done"
