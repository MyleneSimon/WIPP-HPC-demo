#!/usr/bin/env bash

# Install containerd (https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd)
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  
sudo apt-get update
sudo apt-get install containerd.io
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd

# Init k8s cluster
sudo kubeadm init \
          --ignore-preflight-errors=all \
          --apiserver-advertise-address="192.168.60.10" \
          --apiserver-cert-extra-sans="192.168.60.10"  \
          --node-name k8s-master --pod-network-cidr=10.244.0.0/16

mkdir -p /home/vagrant/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
sudo chown vagrant:vagrant /home/vagrant/.kube/config
cp /home/vagrant/.kube/config /sync/etc/config

export IPADDR=$(ifconfig eth1 | grep inet | awk '{print $2}'| cut -f2 -d:)
sudo -E sh -c 'cat >> /etc/systemd/system/kubelet.service.d/10-kubeadm.conf <<EOF
Environment="KUBELET_EXTRA_ARGS=--node-ip=${IPADDR}"
EOF'

# Install Calico network plugin
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

sudo systemctl daemon-reload
sudo systemctl restart kubelet

JOIN_COMMAND=$(kubeadm token create --print-join-command)
cat > /sync/etc/join.sh <<EOF
${JOIN_COMMAND} --ignore-preflight-errors=all --cri-socket='unix:///var/run/singularity.sock'
EOF
