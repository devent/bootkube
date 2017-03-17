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
ExecStartPre=/bin/mkdir -p /var/lib/cni
ExecStartPre=/bin/mkdir -p /var/log/containers
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
  echo "Usage: ./install_k8s_worker.sh CONFIGURATIONFILE"
  exit -1
fi

source $1

changeWorkDir

ssh $WORKER_IP 'if [ ! -d /etc/kubernetes ];then sudo mkdir /etc/kubernetes;fi'
scp /home/core/assets/auth/kubeconfig $WORKER_IP:/home/core
scp /home/core/assets/tls/ca.crt $WORKER_IP:/home/core
ssh $WORKER_IP 'sudo cp /home/core/kubeconfig /etc/kubernetes; sudo cp /home/core/ca.crt /etc/kubernetes'

# Configure and start kubelet.service
echo "Configuring kubelet.service"
configure_kubelet $WORKER_IP 

scp /home/core/kubelet.service $WORKER_IP:/home/core
ssh $WORKER_IP 'sudo mv /home/core/kubelet.service /etc/systemd/system/kubelet.service; sudo systemctl daemon-reload; sudo systemctl enable kubelet; sudo systemctl start kubelet'

echo "Installation done"
