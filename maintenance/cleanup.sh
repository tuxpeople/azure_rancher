#!/bin/bash
# 
# This script will delete everything related to a rancher kubernetes cluster and allows to install a new cluster.
# 
# See also https://rancher.com/docs/rancher/v2.x/en/cluster-admin/cleaning-cluster-nodes/
#

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

docker rm -f $(docker ps -qa)
docker rmi -f $(docker images -q)
docker volume rm $(docker volume ls -q)
for mount in $(mount | grep tmpfs | grep '/var/lib/kubelet' | awk '{ print $3 }') /var/lib/kubelet /var/lib/rancher; do umount $mount; done
rm -rf /etc/ceph \
       /etc/cni \
       /etc/kubernetes \
       /opt/cni \
       /opt/rke \
       /run/secrets/kubernetes.io \
       /run/calico \
       /run/flannel \
       /var/lib/calico \
       /var/lib/etcd \
       /var/lib/cni \
       /var/lib/kubelet \
       /var/lib/rancher/rke/log \
       /var/log/containers \
       /var/log/pods \
       /var/run/calico \
       /var/lib/longhorn/*
reboot
 
