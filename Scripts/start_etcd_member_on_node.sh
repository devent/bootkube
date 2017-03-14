#!/bin/bash

#
# Changes the work directory to the script base directory.
#
function changeWorkDir() {
    DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    cd "$DIR"
}

changeWorkDir

if [ $# -ne 1 ]; then
  echo "Usage: ./start_etcd_member_on_node.sh IPADDRESS"
  exit -1
fi

echo "Starting etcd-member on "$1
ssh $1 'sudo systemctl start etcd-member'
