#!/bin/bash
set -euo pipefail

#
# Changes the work directory to the script base directory.
#
function changeWorkDir() {
  DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  cd "$DIR"
}

#
# Creates the etcd-service for the node.
#
function configure_etcd() {
  echo "Creating etc.service for ${ETCDNAMES[$1]} IP ${ETCDIPS[$1]}"
  INITIAL_CLUSTER=$ETCD_CLUSTER
  
  cat << EOF > /home/core/10-etcd-member.conf
[Service]
Environment="ETCD_IMAGE_TAG=$ETCD_VERSION"
Environment="ETCD_NAME=${ETCDNAMES[$1]}"
Environment="ETCD_INITIAL_CLUSTER=$INITIAL_CLUSTER"
Environment="ETCD_INITIAL_ADVERTISE_PEER_URLS=$ETCD_PROTO://${ETCDIPS[$1]}:2380"
Environment="ETCD_ADVERTISE_CLIENT_URLS=$ETCD_PROTO://${ETCDIPS[$1]}:2379"
Environment="ETCD_LISTEN_CLIENT_URLS=$ETCD_PROTO://0.0.0.0:2379"
Environment="ETCD_LISTEN_PEER_URLS=$ETCD_PROTO://0.0.0.0:2380"
Environment="ETCD_CERT_FILE=/etc/ssl/certs/etcd/${ETCDNAMES[$1]}_cert.pem"
Environment="ETCD_KEY_FILE=/etc/ssl/certs/etcd/${ETCDNAMES[$1]}_key_insecure.pem"
Environment="ETCD_PEER_CERT_FILE=/etc/ssl/certs/etcd/${ETCDNAMES[$1]}_cert.pem"
Environment="ETCD_PEER_KEY_FILE=/etc/ssl/certs/etcd/${ETCDNAMES[$1]}_key_insecure.pem"
Environment="ETCD_PEER_TRUSTED_CA_FILE=/etc/ssl/certs/etcd/ca_cert.pem"
Environment="ETCD_PEER_CLIENT_CERT_AUTH=true"

EOF
}

#
# Install etcd-member service on all three nodes
#
function install_etcd_nodes() {
  rm -rf /home/core/.etcd_private; true
  git clone $GIT_PRIVATE_BRANCH $GIT_PRIVATE_REPO /home/core/.etcd_private
  for (( node=0; node<${#ETCDIPS[@]}; node++ ));do
  #for node in 0 1 2;do
  echo "etcd for node "$node
  configure_etcd $node
  scp -r /home/core/.etcd_private/etcd ${ETCDIPS[$node]}:/tmp/
  scp /home/core/10-etcd-member.conf ${ETCDIPS[$node]}:/tmp/
  ssh ${ETCDIPS[$node]} '\
  sudo cp /tmp/etcd /etc/ssl/certs; \
  rm -rf /tmp/etcd; \
  sudo systemctl stop etcd-member; \
  if [ -d /etc/systemd/system/etcd-member.service.d ];then sudo rm -rf /etc/systemd/system/etcd-member.service.d; fi; \
  sudo mkdir /etc/systemd/system/etcd-member.service.d'
  ssh ${ETCDIPS[$node]} 'sudo rm -rf /var/lib/etcd/*; sudo mv /tmp/10-etcd-member.conf /etc/systemd/system/etcd-member.service.d/; sudo systemctl daemon-reload; sudo systemctl enable etcd-member'
  ./start_etcd_member_on_node.sh ${ETCDIPS[$node]} &
  done
}

#
# Installation of etcdctl in /home/core/bin
#
function install_etcdctl() {
  echo "Install etcdctl v3"

  if [ ! -d "/home/core/bin" ]; then
    mkdir -p /home/core/bin

    DOWNLOAD_URL=https://github.com/coreos/etcd/releases/download
    curl -L ${DOWNLOAD_URL}/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VERSION}-linux-amd64.tar.gz
    mkdir -p /tmp/test-etcd && tar xzvf /tmp/etcd-${ETCD_VERSION}-linux-amd64.tar.gz -C /tmp/test-etcd --strip-components=1
    cp /tmp/test-etcd/etcdctl /home/core/bin

  cat << EOF > /home/core/bin/environment.txt
export PATH=$PATH:/home/core/bin
export ETCDCTL_API=3
export ETCDCTL_DIAL_TIMEOUT=3s
export ETCDCTL_ENDPOINTS=$ETCD_ENDPOINTS
export ETCDCTL_CACERT=/etc/ssl/certs/etcd/ca_cert.pem
export ETCDCTL_CERT=/etc/ssl/certs/etcd/client_cert.pem
export ETCDCTL_KEY=/etc/ssl/certs/etcd/client_key_insecure.pem

EOF
  fi
}

if [ $# -ne 1 ]; then
  echo "Usage: ./install_etcd_cluster.sh CONFIGURATIONFILE"
  exit -1
fi

source $1 

changeWorkDir
install_etcd_nodes
install_etcdctl

for i in `seq 10`; do
 echo "Waiting .."
 sleep 3
done

echo "Installation of etcd done"

source /home/core/bin/environment.txt
/home/core/bin/etcdctl member list
