#!/bin/bash
set -x

R_REMOTEIP=13.95.171.76
R_LOCALIP=10.0.0.4
R_NODEUSER=rancher
R_NODEFQDN=rancher-toolset.westeurope.cloudapp.azure.com
RKE_VERSION=1.0.6
HELM_VERSION=3.1.2
CERTMANAGER_VERSION=0.14.2
LETSENCRYPTMAIL=me@default.com
DOCKER_VERSION=19.03

PARAMS_FILE=params.txt
if [[ -f "$PARAMS_FILE" ]]; then
    . $PARAMS_FILE
fi

sudo apt-get update -q && sudo apt-get upgrade -yq
sudo apt autoremove -yq
sudo apt-get install -yq vim apt-transport-https curl

#sudo apt-get install -yq docker.io
#sudo bash -c 'cat > /etc/docker/daemon.json <<EOF
#{
#  "exec-opts": ["native.cgroupdriver=systemd"],
#  "log-driver": "json-file",
#  "log-opts": {
#    "max-size": "100m"
#  },
#  "storage-driver": "overlay2"
#}
#EOF'
#sudo systemctl enable docker.service
#sudo systemctl start docker

curl https://releases.rancher.com/install-docker/${DOCKER_VERSION}.sh | sh

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

CLUSTER_FILE=rancher-cluster.yml
if [ ! -f "$CLUSTER_FILE" ]; then
cat << EOF > rancher-cluster.yml
nodes:
  - address: ${R_REMOTEIP}
    internal_address: ${R_LOCALIP}
    user: ${R_NODEUSER}
    role: [controlplane,etcd,worker]
addon_job_timeout: 120
EOF
fi

rke up --config rancher-cluster.yml

mkdir -p ~/.kube
ln -s ~/kube_config_rancher-cluster.yml ~/.kube/config

kubectl create namespace cert-manager
kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-$(echo ${CERTMANAGER_VERSION} | cut -d'.' -f1-2)/deploy/manifests/00-crds.yaml
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install   cert-manager --namespace cert-manager   --version v${CERTMANAGER_VERSION}.0   jetstack/cert-manager
kubectl -n cert-manager rollout status deploy/cert-manager
kubectl -n cert-manager rollout status deploy/cert-manager-webhook

sleep 60

helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update
kubectl create namespace cattle-system

helm install rancher rancher-latest/rancher \
    --namespace cattle-system \
    --set hostname=${R_NODEFQDN} \
    --set replicas=1 \
    --set ingress.tls.source=letsEncrypt \
    --set letsEncrypt.email=${LETSENCRYPTMAIL}

kubectl -n cattle-system rollout status deploy/rancher

set +x

while true; do curl -kv https://rancher-test.umb.cloud 2>&1 | grep -q "Let's Encrypt Authority"; if [ $? != 0 ]; then echo "Rancher isn't ready yet"; sleep 5; continue; fi; break; done; echo "Rancher is Ready";
