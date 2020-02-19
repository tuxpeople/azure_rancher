#!/bin/bash

AZ_GROUP=RANCHER
AZ_LOCATION=westeurope
R_NODENAME=rancher
R_NODEUSER=tuxpeople
R_NODESSH="~/.ssh/id_rsa.pub"




R_NODEDNS=${R_NODENAME}-$(cat /dev/urandom | LC_CTYPE=C tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
R_NODEFQDN=${R_NODEDNS}.${AZ_LOCATION}.cloudapp.azure.com

az group create --name ${AZ_GROUP} --location ${AZ_LOCATION}

az vm create \
  --resource-group ${AZ_GROUP} \
  --name ${R_NODENAME} \
  --image UbuntuLTS \
  --admin-username ${R_NODEUSER} \
  --size Standard_B2s \
  --public-ip-address-dns-name ${R_NODEDNS} \
  --ssh-key-value ${R_NODESSH}

az vm open-port --resource-group ${AZ_GROUP} --name ${R_NODENAME} --port "*"

echo "R_REMOTEIP=$(az vm list-ip-addresses -n ${R_NODENAME} | grep ipAddress | cut -d'"' -f4)" > params.txt
echo "R_LOCALIP=$(az vm list-ip-addresses -n ${R_NODENAME} | grep -A 1 privateIpAddresses | tail -1 | cut -d'"' -f2)" >> params.txt
echo "R_NODEUSER=${R_NODEUSER}" >> params.txt
echo "R_NODEFQDN=${R_NODEFQDN}" >> params.txt

scp install.sh ${R_NODEUSER}@${R_NODEFQDN}:
scp params.txt ${R_NODEUSER}@${R_NODEFQDN}:
ssh ${R_NODEUSER}@${R_NODEFQDN} "chmod +x install.sh"
ssh ${R_NODEUSER}@${R_NODEFQDN} ./install.sh
