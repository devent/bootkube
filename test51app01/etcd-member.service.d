[Service]
Environment="ETCD_IMAGE_TAG=v3.1.0"
Environment="ETCD_NAME=master1"
Environment="ETCD_INITIAL_CLUSTER=master1=http://10.104.12.80:2380,master2=http://10.104.12.89:2380,master3=http://10.104.12.81:2380"
Environment="ETCD_INITIAL_ADVERTISE_PEER_URLS=http://10.104.12.81:2380"
Environment="ETCD_ADVERTISE_CLIENT_URLS=http://10.104.12.81:2379"
Environment="ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379"
Environment="ETCD_LISTEN_PEER_URLS=http://0.0.0.0:2380"