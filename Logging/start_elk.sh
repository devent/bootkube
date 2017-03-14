#!/bin/bash

sudo sysctl -w vm.max_map_count=262144
docker run -d -p 9200:9200 --name local-elas elasticsearch -Etransport.host=0.0.0.0 -Ediscovery.zen.minimum_master_nodes=1
docker run --name local-kibana -e ELASTICSEARCH_URL=http://10.104.100.236:9200 -p 5601:5601 -d kibana
