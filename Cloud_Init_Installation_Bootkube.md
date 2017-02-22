# Installation of Kubernetes with the help of Bootkube and Cloud-Config

This document describes the steps to install Kubernetes with the help of Bootkube and Cloud-Config on systems:

* prod00kube01.ams01.service.moovel.ibm.com - name node1 - IP 10.104.100.236 - public IP 37.58.99.228
* prod00kube02.ams01.service.moovel.ibm.com - name node2 - IP 10.104.100.245 - public IP 37.58.99.235
* prod00kube03.ams01.service.moovel.ibm.com - name node3 - IP 10.104.100.239 - public IP 37.58.99.238

All three systems will be installed as Kubernetes master. A prerequisite is that a working etcd cluster is installed.






### How to remove an existing Kubernetes installation in SL if OS reload is not an option

Perform the following steps on all Kubernetes masters

* systemctl stop etcd-member  
* rm -rf /var/lib/etcd/\*  
* systemctl stop kubelet  
* remove all docker containers  
    * for i in \`docker ps | grep -v \^CON | awk '{print $1}'\`;do docker rm -f $i;done  
* remove all docker images  
    * for i in \`docker images | grep -v \^REPO | awk '{print $3}'\`;do docker rmi -f $i;done  

