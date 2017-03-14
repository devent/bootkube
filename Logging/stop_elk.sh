#!/bin/bash

KIBANA=`docker ps | grep local-elas | awk '{print $1}'`
ELASTIC=`docker ps | grep local-kibana | awk '{print $1}'`

sudo docker rm -f $KIBANA 
sudo docker rm -f $ELASTIC
