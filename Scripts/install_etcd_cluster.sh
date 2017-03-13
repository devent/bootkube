#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: ./install_etcd_cluster.sh CONFIGURATIONFILE"
    exit -1
fi

source $1 

IFS=',' read -r -a ips <<< "$ETCD_IP"
IFS=',' read -r -a names <<< "$ETCD_NAME"

function configure_etcd() {

  echo "Creating etc.service for ${names[$1]} IP ${ips[$1]}"

  cat << EOF > /home/core/10-etcd-member.conf
[Service]
Environment="ETCD_IMAGE_TAG=$ETCD_VERSION"
Environment="ETCD_NAME=${names[$1]}"
Environment="ETCD_INITIAL_CLUSTER=${names[0]}=http://${ips[0]}:2380,${names[1]}=http://${ips[1]}:2380,${names[2]}=http://${ips[2]}:2380"
Environment="ETCD_INITIAL_ADVERTISE_PEER_URLS=http://${ips[$1]}:2380"
Environment="ETCD_ADVERTISE_CLIENT_URLS=http://${ips[$1]}:2379"
Environment="ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379"
Environment="ETCD_LISTEN_PEER_URLS=http://0.0.0.0:2380"

EOF
}

# Install etcd-member service on all three nodes
for node in 0 1 2;do
  echo "etcd for node "$node
  configure_etcd $node 
  scp /home/core/10-etcd-member.conf ${ips[$node]}:/tmp/
  ssh ${ips[$node]} 'sudo systemctl stop etcd-member; if [ -d /etc/systemd/system/etcd-member.service.d ];then sudo rm -rf /etc/systemd/system/etcd-member.service.d; fi; sudo mkdir /etc/systemd/system/etcd-member.service.d'
  ssh ${ips[$node]} 'sudo rm -rf /var/lib/etcd/*; sudo mv /tmp/10-etcd-member.conf /etc/systemd/system/etcd-member.service.d/; sudo systemctl daemon-reload; sudo systemctl enable etcd-member'
  ./start_etcd_member_on_node.sh ${ips[$node]} &
    
done

for i in `seq 10`; do
 echo "Waiting .."
 sleep 3
done

  # Installation of etcdctl in /home/core/bin
  echo "Checking for prerequisites ..."

  if [ ! -d "/home/core/bin" ]; then
    mkdir -p /home/core/bin

    DOWNLOAD_URL=https://github.com/coreos/etcd/releases/download
    curl -L ${DOWNLOAD_URL}/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VERSION}-linux-amd64.tar.gz
    mkdir -p /tmp/test-etcd && tar xzvf /tmp/etcd-${ETCD_VERSION}-linux-amd64.tar.gz -C /tmp/test-etcd --strip-components=1
    cp /tmp/test-etcd/etcdctl /home/core/bin

  
cat << EOF > /home/core/bin/environment.txt
  export PATH=$PATH:/home/core/bin
  export ETCDCTL_API=3

EOF
  
  fi


echo "Installation of etcd done"
ETCDCTL_API=3 /home/core/bin/etcdctl member list
