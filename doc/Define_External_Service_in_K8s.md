# How to define an external service in K8s 

The complete documentation can be found here [https://kubernetes.io/docs/user-guide/services/#defining-a-service](https://kubernetes.io/docs/user-guide/services/#defining-a-service).

If you need, for example, access to an external database from within the K8s cluster then you can define a service without selectors. The files *mysql2_service.json* abd *mysql2_endpoint* define an external service, called mysql2, which can be accessed via this name from within K8s. Adjust the configuration to your needs.

* kubectl apply -f mysql2_service.json
* kubectl apply -f mysql2_endpoint.json

To check if it worked execute *kubectl get services*. You should see an output similar to the follwoing one:

NAME | CLUSTER-IP | EXTERNAL-IP | PORT(S) | AGE
---  | ---        | ---         | ---     | ---
mysql2 |       10.3.0.120 |   <none> |        3306/TCP |       22m


To see the corresponding endpoints execute *kubectl get endpoints*:

NAME | ENDPOINTS | AGE
--- | --- | ---
mysql2 | 10.104.100.236:3306 | 25m


From within a pod you can now access the mysql2 server *mysql -h mysql2 ...*

Alternatively, you can also specify an *ExternalName* in the service file if DNS should be used instead of a static IP address.
