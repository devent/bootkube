# Installation of Kubernetes with the help of a bash script

The bash script desribed in this document automatically installs three K8s master nodes. 

## Prerequisites and limitations

### ETCD

The bash script does not consider the installation of an etcd cluster. The script can be extended, but currently an etcd cluster must be available. 
The corresponding etcd IP addresses are configured in the beginning of the script.

### IP addresses of K8s master nodes

The IP address of all three K8s master nodes must be specified upfront in the bash script. The IP addresses must be considered when creating certificates. In future this can be mitigated
by the introduction of load balancers.

### Persistent Storage

No persistent storage is currently available in the K8s cluster

### Registry

The script fetches current images from the Internet. A local registry is not set up currently.

## Installation

* Checkout the script *install_k8s_3_nodes.sh*
* Configure the IP addresses
    * Private IP addresses of Kubernetes API server
    * Public IP addresses of Kubernetes API server
    * IP addresses of etcd cluster (three etcd nodes are assumed)
* Copy the script to the first K8s master nodes
* Distribute your public ssh keys to the additional master nodes (user core)
* Launch the script and wait for around 10 minutes

You should end up with:
* a high available three node Kubernetes cluster
* Kubernetes dashboard
* Heapster (for monitoring)

In order to access the dashboard you need to:
* copy the file */home/core/assets/auth/admin-kubeconfig* to the jumpserver
* download kubectl to the jumpserver (or you can use /home/andreas.hess/tools/kubectl)
* execute the following command *./kubectl --kubeconfig=PATH-TO-ADMIN-KUBECONFIG proxy* --port=xxxx (default port is 8001)
* use a tunnel or a socks proxy to access the Kubernetes via the proxy (http://localhost:8001/ui)

To access Heapster, execute the command *./kubectl --kubeconfig=admin-kubeconfig describe services monitoring-grafana -n=kube-system*.
The output should look similar to the following:

Name:              |    monitoring-grafana
Namespace:         |    kube-system
Labels:            |    kubernetes.io/cluster-service=true
                   |    kubernetes.io/name=monitoring-grafana
Selector:          |    k8s-app=grafana
Type:              |    NodePort
IP:                |    10.3.0.86
Port:              |    <unset> 80/TCP
NodePort:          |    <unset> 31061/TCP
Endpoints:         |    10.2.1.11:3000
Session Affinity:  |    None
No events.

You need to use the NodePort to access the NodePort. In your browser (again you need either a tunnel or a socks proxy) enter the address *http://PRIVATE-IP-ADDRESS-OF-A-K8Node:NodePort*
