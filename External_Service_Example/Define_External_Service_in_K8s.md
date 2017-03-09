# How to define an external service in K8s 

If you need, for example, access to an external service from within the K8s cluster then define a service without selectors. In the repository two examples are given:

* files *web1_service_ip.json* and *web1_endpoint* show how to define an external service using the corresponding IP address
* file *web2_service_name.json* show how to define an alias for for an external service. No endpoint is defined.

Adjust the file according to your needs and apply them

* kubectl apply -f web1_service_ip.json
* kubectl apply -f web1_endpoint.json
* kubectl apply -f web2_service_name.json

To check if it worked execute *kubectl get services*. You should see an output similar to the follwoing one:

NAME | CLUSTER-IP | EXTERNAL-IP | PORT(S) | AGE
---  | ---        | ---         | ---     | ---
web1 |       10.3.0.120 |   <none> |        80/TCP |       22m
web2 |            | EXTERNALNAME | 8080/TCP | 1h 


To see the corresponding endpoint execute *kubectl get endpoints*:

NAME | ENDPOINTS | AGE
--- | --- | ---
web1 | External-IP-Address | 25m


From within a pod you can do the following for example:

* curl web1 (this will connect to http://External-IP-Address:8080 - the port was defined in the files)
* curl web2 (this will connect to http://EXTERNALNAME - the port needs to be specified in the command)

The official documentation can be found here [https://kubernetes.io/docs/user-guide/services/#defining-a-service](https://kubernetes.io/docs/user-guide/services/#defining-a-service).
