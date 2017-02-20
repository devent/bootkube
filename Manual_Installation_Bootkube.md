# Manual installation of Kubernetes with Bootkube  

This document describes the steps to manually install Kubernetes with the help of [Bootkube](https://github.com/kubernetes-incubator/bootkube) on the following systems:
* prod00kube01.ams01.service.moovel.ibm.com
* prod00kube02.ams01.service.moovel.ibm.com
* prod00kube03.ams01.service.moovel.ibm.com

On all three systems Container Linux is already installed. In addition, all three systems acts as:
* etcd server and
* Kubernetes master

The result is a high available Kubernetes cluster consisting of three nodes.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

