#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: ./start_etcd_member_on_node.sh IPADDRESS"
  exit -1
fi

echo "Starting etcd-member on "$1
ssh $1 'sudo systemctl start etcd-member'
