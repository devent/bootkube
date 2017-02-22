#!/bin/bash

systemctl stop etcd-member
rm -rf /var/lib/etcd/* 
systemctl stop kubelet
systemctl disable kubelet
rm -f /etc/systemd/system/kubelet.service

for i in `docker ps --all | grep -v \^CON | awk '{print $1}'`;do docker rm -f $i;done
for i in `docker images | grep -v \^REPO | awk '{print $3}'`;do docker rmi -f $i;done

for i in `rkt list | grep -v \^UUID | awk '{print $1}'`;do rkt rm $i;done
for i in `rkt image list | grep -v \^ID | awk '{print $1}'`;do rkt image rm $i;done

rm -rf /home/core/assets
rm -rf /etc/kubernetes