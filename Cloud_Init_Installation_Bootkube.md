# Installation of Kubernetes with the help of Bootkube and Cloud-Config

This document describes the steps to install Kubernetes with the help of Bootkube and Cloud-Config on systems:

* prod00kube01.ams01.service.moovel.ibm.com - name node1 - IP 10.104.100.236 - public IP 37.58.99.228
* prod00kube02.ams01.service.moovel.ibm.com - name node2 - IP 10.104.100.245 - public IP 37.58.99.235
* prod00kube03.ams01.service.moovel.ibm.com - name node3 - IP 10.104.100.239 - public IP 37.58.99.238

All three systems will be installed as Kubernetes master. A prerequisite is that a working etcd cluster is installed.

## Manually triggering the cloud-config process

When we deploy a Container Linux system via the SL API a cloud config file can be specified. However, this is currently not possible and hence we manually trigger the process.






### How to remove an existing Kubernetes installation in SL if OS reload is not an option

Perform the following steps on all Kubernetes masters

* systemctl stop etcd-member (if running) 
* rm -rf /var/lib/etcd/\*  (if running)
* systemctl stop kubelet  
* systemctl disable kubelet
* rm -f /etc/systemd/system/kubelet.service
* remove all docker containers
    * for i in \`docker ps --all | grep -v \^CON | awk '{print $1}'\`;do docker rm -f $i;done  
* remove all docker images
    * for i in \`docker images | grep -v \^REPO | awk '{print $3}'\`;do docker rmi -f $i;done  
* remove all rkt containers
    * for i in \`rkt list | grep -v \^UUID | awk '{print $1}'\`;do rkt rm $i;done
* remove all rkt images
    *  for i in \`rkt image list | grep -v \^ID | awk '{print $1}'\`;do rkt image rm $i;done
* rm -rf /home/core/assets
* rm -rf /etc/kubernetes
* reboot

After the reboot you should end up with three systems running etcd-member. Please check if the etcd cluster is ready (ETCDCTL_API=3 /home/core/bin/etcdctl member list).

