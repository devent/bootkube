# Logging with fluentd

With the script start_elk.sh a local instance of elasticsearch and kibana will be started. Please adjust the script according to your needs.

Additionally, start the daemonset fluentd-daemonset-elasticsearch.yaml (kubectl apply -f fluentd-daemonset-elasticsearch.yaml). All container log files will be sent to the elasticsearch instance. The entries can be viewed with kibana. The approach uses [https://github.com/fluent/fluentd-kubernetes-daemonset](https://github.com/fluent/fluentd-kubernetes-daemonset).
