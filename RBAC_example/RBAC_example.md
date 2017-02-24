# A short demonstration of RBAC in K8s

Ensure that K8s itself has the rights it needs:

* kubectl create -f /home/core/bootkube/RBAC_example/system-access.yml 

Create a namespace *dev*, a role *dev-all* and a rolebinding *dev-role-dev-all-members*:

* kubectl create -f /home/core/bootkube/RBAC_example/dev-access.yml 

Create a client certificate

* openssl genrsa -out client.key 2048
* openssl req -new -key client.key -out client.csr -subj "/CN=fred/O=dev"
* openssl x509 -req -in client.csr -CA /home/core/assets/tls/ca.crt -CAkey /home/core/assets/tls/ca.key -CAcreateserial -out client.crt -days 10000

Create kubeconfig for user fred (see file fred-kubeconfig.yml).

Use kubectl and the created fred-kubeconfig to test the rights of user fred.
