#!/bin/bash

systemctl stop etcd-member
systemctl disable etcd-member
rm -rf /etc/systemd/system/etcd-member.service.d
rm -rf /var/lib/etcd/*
rm -rf /tmp/test-etcd
systemctl stop kubelet
systemctl stop docker
systemctl disable kubelet
rm -f /etc/systemd/system/kubelet.service

for i in `docker ps --all | grep -v \^CON | awk '{print $1}'`;do docker rm -f $i;done
for i in `docker images | grep -v \^REPO | awk '{print $3}'`;do docker rmi -f $i;done

for i in `rkt list | grep -v \^UUID | awk '{print $1}'`;do rkt rm $i;done
for i in `rkt image list | grep -v \^ID | awk '{print $1}'`;do rkt image rm $i;done

rm -rf /home/core/assets
rm -rf /home/core/bin
rm -rf /etc/kubernetes

rm -f /home/core/.k8s_installed

for i in `mount | grep /var/lib/kubelet | awk '{print $3}'`;do umount $i;done
rm -rf /var/lib/kubelet/*
rm -rf /var/log/containers
rm -rf /var/lib/cni/

ifconfig cni0 down
ifconfig flannel.1 down
ifconfig docker0 down

systemctl start docker
