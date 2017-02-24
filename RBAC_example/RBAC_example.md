# A short demonstration of RBAC in K8

Ensure that K8s has the rights it needs:

* kubectl create -f /home/core/bootkube/RBAC_example/system-access.yml 

Create a namespace *dev*, a role *dev-all* and a rolebinding *dev-role-dev-all-members*:

* kubectl create -f /home/core/bootkube/RBAC_example/dev-access.yml 

Create a client certificate

* openssl genrsa -out client.key 2048
* openssl req -new -key client.key -out client.csr -subj "/CN=fred/O=dev"
* openssl x509 -req -in client.csr -CA /home/core/assets/tls/ca.crt -CAkey /home/core/assets/tls/ca.key -CAcreateserial -out client.crt -days 10000

Create kubeconfig for user fred:

apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: BASE64_ENCODED_CA_CERTIFICATE
    server: https://x.x.x.x:443
  name: local
contexts:
- context:
    cluster: local
    namespace: dev
    user: fred 
  name: local-dev
current-context: local-dev
kind: Config
preferences: {}
users:
- name: fred 
  user:
    client-certificate-data: BASE64_ENCODED_CLIENT_CERTIFICATE
    client-key-data: BASE64_ENCODED_CLIENT_KEY


Use kubectl and the created kubeconfig to test the rights of user fred.
