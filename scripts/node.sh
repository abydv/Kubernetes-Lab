#!/bin/bash
#
# Setup for Node servers

set -euxo pipefail

config_path="/vagrant/configs"
api_server="192.168.26.10:6443"

echo "Waiting for Kubernetes API server at ${api_server}..."
until curl -k --silent --output /dev/null "https://${api_server}/healthz"; do
  echo "API server is not ready yet. Retrying in 10 seconds..."
  sleep 10
done

echo "Waiting for join command to be generated in $config_path/join.sh..."
until [ -s "$config_path/join.sh" ] && grep -q '^kubeadm join' "$config_path/join.sh"; do
  echo "Join script not ready yet. Retrying in 10 seconds..."
  sleep 10
done

chmod +x $config_path/join.sh
/bin/bash $config_path/join.sh -v

sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
NODENAME=$(hostname -s)
kubectl label node $(hostname -s) node-role.kubernetes.io/worker=worker
EOF
