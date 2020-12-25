#!/bin/bash

# Vars to adjust
AZ_GROUP=RANCHER
AZ_LOCATION=westeurope
R_NODENAME=rancher
R_NODEUSER=rancher
R_NODESSH="~/.ssh/id_rsa.pub"
LETSENCRYPTMAIL=me@default.com
DOCKER_VERSION="19.03"

# Vars which get auto assembled
R_NODEDNS=${R_NODENAME}-$(cat /dev/urandom | LC_CTYPE=C tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
R_NODEFQDN=${R_NODEDNS}.${AZ_LOCATION}.cloudapp.azure.com

# create Ressource Group
az group create --name ${AZ_GROUP} --location ${AZ_LOCATION}

# Create VM
az vm create \
  --resource-group ${AZ_GROUP} \
  --name ${R_NODENAME} \
  --image OpenLogic:CentOS-LVM:7-lvm-gen2:7.8.2020062401 \
  --admin-username ${R_NODEUSER} \
  --size Standard_B2s \
  --public-ip-address-dns-name ${R_NODEDNS} \
  --ssh-key-value ${R_NODESSH}

# Open all doors
az vm open-port --resource-group ${AZ_GROUP} --name ${R_NODENAME} --port "*"

# get versions
RKE_VERSION=$(lynx https://github.com/rancher/rke/releases/latest -dump -hiddenlinks=listonly | grep download | cut -d'/' -f8 | head -1 | sed 's/v//')
HELM_VERSION=$(lynx https://github.com/helm/helm/releases -dump -hiddenlinks=listonly | grep /helm/helm/releases/tag/v3. | grep -v no-underline | head -n 1 | cut -d'/' -f8 | sed 's/v//')
CERTMANAGER_VERSION=$(lynx https://github.com/jetstack/cert-manager/releases/latest -dump -hiddenlinks=listonly | grep download | cut -d'/' -f8 | head -1 | sed 's/v//')

# Creating params file for stage 2
echo "R_REMOTEIP=$(az vm list-ip-addresses -n ${R_NODENAME} | grep ipAddress | cut -d'"' -f4)" > params.txt
echo "R_LOCALIP=$(az vm list-ip-addresses -n ${R_NODENAME} | grep -A 1 privateIpAddresses | tail -1 | cut -d'"' -f2)" >> params.txt
echo "R_NODEUSER=${R_NODEUSER}" >> params.txt
echo "R_NODEFQDN=${R_NODEFQDN}" >> params.txt
echo "RKE_VERSION=${RKE_VERSION}" >> params.txt
echo "HELM_VERSION=${HELM_VERSION}" >> params.txt
echo "CERTMANAGER_VERSION=${CERTMANAGER_VERSION}" >> params.txt
echo "LETSENCRYPTMAIL=${LETSENCRYPTMAIL}" >> params.txt
echo "DOCKER_VERSION=${DOCKER_VERSION}" >> params.txt

# Get Hostkeys
ssh-keygen -R ${R_NODEFQDN}
ssh-keyscan -H ${R_NODEFQDN} >> ~/.ssh/known_hosts

# Upload stage 2 and params to new vm and execute it
scp install.sh ${R_NODEUSER}@${R_NODEFQDN}:
scp params.txt ${R_NODEUSER}@${R_NODEFQDN}:
ssh ${R_NODEUSER}@${R_NODEFQDN} "chmod +x install.sh"
#ssh ${R_NODEUSER}@${R_NODEFQDN} ./install.sh

echo ""
echo "Rancher is at https://${R_NODEFQDN}"
echo ""
echo "To delete everything, use the following command:"
echo "    az group delete --name ${AZ_GROUP}"

# Cleanup
rm params.txt
