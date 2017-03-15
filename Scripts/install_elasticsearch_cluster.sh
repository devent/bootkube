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
# Creates the elasticsearch configuration for the node.
#
function configure_elasticsearch() {
  echo "Creating elasticsearch configuration for $EL_CLUSTER IP ${ELIPS[$1]}"

  cat << EOF > /tmp/elasticsearch.yml
network.host: 0.0.0.0

cluster:
  name: "$EL_CLUSTER"

EOF
}

#
# Install elasticsearch service on all three nodes
#
function install_elasticsearch_nodes() {
  for (( node=0; node<${#ELIPS[@]}; node++ ));do
  #for node in 0 1 2;do
  echo "elasticsearch for node "$node
  configure_etcd $node 
  scp /tmp/elasticsearch.yml ${ELIPS[$node]}:/tmp/
  ssh ${ELIPS[$node]} "\
  sudo mkdir /srv/el/$EL_CLUSTER/conf /srv/el/$EL_CLUSTER/data /srv/el/$EL_CLUSTER/templates; \
  sudo mv /tmp/elasticsearch.yml /srv/el/$EL_CLUSTER/conf/; \
  sudo docker run --name "$DATA_NAME" \
        $EL_LOG \
        $EL_VOLUMES \
        $EL_IMAGE \
        bash -c 'chown -R elasticsearch:elasticsearch /usr/share/elasticsearch/data && chmod -R o+rX /usr/share/elasticsearch/data'; \
  sudo docker run -d --name "$EL_NAME" \
        $EL_ARGS \
        --volumes-from=$EL_DATA_NAME \
        $EL_CONFIGS \
        $EL_PORTS \
        $EL_ENVS \
        $EL_IMAGE
  "
  done
}

if [ $# -ne 1 ]; then
  echo "Usage: ./install_elasticsearch_cluster.sh CONFIGURATIONFILE"
  exit -1
fi

source $1 

changeWorkDir
configure_elasticsearch
install_elasticsearch_nodes
