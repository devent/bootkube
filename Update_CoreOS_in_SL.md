# How to update Container Linux in SL

Currrently, SL deploys Container Linux version 1010.5.0 which is rather old and lacks certain features. In addition, SL does not specify an update strategy and consequently no update would be applied to Container Linux. 

In order to update to a current version you have to perform the following steps:

* vim /etc/coreos/update.conf (specify the strategy as depicted)  
GROUP=stable  
REBOOT_STRATEGY=etcd-lock
* systemctl restart locksmithd
* update_engine_client -update
* reboot

After the reboot the current version of Container Linux should be installed
