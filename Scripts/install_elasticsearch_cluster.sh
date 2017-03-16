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
  node=$1
  ip=${ELIPS[$node]}
  name=${ELNAMES[$node]}
  echo "Creating elasticsearch configuration for $EL_CLUSTER_NAME IP $ip"

  cat << EOF > /tmp/elasticsearch.yml
network.host: 0.0.0.0
discovery.zen.ping.unicast.hosts: [$EL_ENDPOINTS]
node.name: $name

cluster:
  name: "$EL_CLUSTER_NAME"

EOF
}

#
# Install elasticsearch service on all three nodes
#
function install_elasticsearch_nodes() {
  node=$1
  ip=${ELIPS[$node]}
  echo "elasticsearch for node $node"
  configure_elasticsearch $node 
  scp /tmp/elasticsearch.yml $ip:/tmp/
  cat << EOF > /home/core/install_el.sh
sudo mkdir -p /srv/el/$EL_CLUSTER_NAME/conf /srv/el/$EL_CLUSTER_NAME/data /srv/el/$EL_CLUSTER_NAME/templates
sudo mv /tmp/elasticsearch.yml /srv/el/$EL_CLUSTER_NAME/conf/
mv /tmp/elasticsearch.yml /srv/el/$EL_CLUSTER_NAME/conf/
if ! docker ps -a | egrep '^.*\s+$EL_DATA_NAME\$'; then
sudo docker run --name "$EL_DATA_NAME" $EL_LOG $EL_VOLUMES $EL_IMAGE \
  bash -c 'chown -R elasticsearch:elasticsearch /usr/share/elasticsearch/data && chmod -R o+rX /usr/share/elasticsearch/data'
fi
if ! docker ps | egrep '^.*\s+$EL_NAME\$'; then
  sudo docker run -d --name $EL_NAME $EL_ARGS --volumes-from=$EL_DATA_NAME $EL_CONFIGS $EL_PORTS $EL_ENVS $EL_IMAGE
fi

EOF
  ssh $ip bash -xc /home/core/install_el.sh
}

if [ $# -ne 1 ]; then
  echo "Usage: ./install_elasticsearch_cluster.sh CONFIGURATIONFILE"
  exit -1
fi

source $1 

changeWorkDir
  for (( node=0; node<${#ELIPS[@]}; node++ ));do
  install_elasticsearch_nodes $node
done
