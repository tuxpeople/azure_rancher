#!/bin/bash

. params.txt

sudo apt-get update -q && sudo apt-get upgrade -yq
sudo apt autoremove -yq
sudo apt-get install -yq docker.io vim apt-transport-https curl
sudo bash -c 'cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF'
sudo systemctl enable docker.service
sudo systemctl start docker
sudo usermod -a -G docker ${R_NODEUSER}

ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -N ""
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

sudo wget -O /usr/local/bin/rke -q https://github.com/rancher/rke/releases/download/v${RKE_VERSION}/rke_linux-amd64
sudo chmod +x /usr/local/bin/rke

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -q
sudo apt-get install -yq kubectl

sudo wget -O helm.tar.gz -q https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz
sudo tar -zxf helm.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
sudo chmod +x /usr/local/bin/helm
sudo rm -rf linux-amd64
sudo rm -f helm.tar.gz

cat << EOF > rancher-cluster.yml
nodes:
  - address: ${R_REMOTEIP}
    internal_address: ${R_LOCALIP}
    user: ${R_NODEUSER}
    role: [controlplane,etcd,worker]
addon_job_timeout: 120
EOF

rke up --config rancher-cluster.yml

mkdir -p ~/.kube
ln -s ~/kube_config_rancher-cluster.yml ~/.kube/config

kubectl create namespace cert-manager
kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-${CERTMANAGER_VERSION}/deploy/manifests/00-crds.yaml
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install   cert-manager --namespace cert-manager   --version v${CERTMANAGER_VERSION}.0   jetstack/cert-manager
kubectl -n cert-manager rollout status deploy/cert-manager
kubectl -n cert-manager rollout status deploy/cert-manager-webhook

sleep 60

helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update
kubectl create namespace cattle-system

helm install rancher rancher-latest/rancher   --namespace cattle-system   --set hostname=${R_NODEFQDN}   --set replicas=1   --set 'extraEnv[0].name=CATTLE_INGRESS_IP_DOMAIN'   --set 'extraEnv[0].value=on.hobbyfarm.io'
while true; do curl -kv https://${R_NODEFQDN} 2>&1 | grep -q "cattle-ca"; if [ $? != 0 ]; then echo "Rancher isn't ready yet"; sleep 5; continue; fi; break; done; echo "Rancher is Ready";
