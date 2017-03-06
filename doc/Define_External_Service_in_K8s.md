# How to define an external service in K8s 

The complete documentation can be found here [https://kubernetes.io/docs/user-guide/services/#defining-a-service](https://kubernetes.io/docs/user-guide/services/#defining-a-service).

If you need, for example, access to an external database from within the K8s cluster then you can define a service without selectors. The following example defines an external database and the corresponding endpoint.

{
    "kind": "Service",  
    "apiVersion": "v1",  
    "metadata": {  
        "name": "mysql2"  
    },
    "spec": {  
        "ports": [  
            { 
                "protocol": "TCP",  
                "port": 3306  
            }  
        ]  
    }   
}   
