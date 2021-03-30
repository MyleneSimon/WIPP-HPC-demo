#!/usr/bin/env bash

sudo chmod +x /sync/etc/join.sh 
sudo /sync/etc/join.sh
mkdir .kube && cp /sync/etc/config .kube/config

# install go
export VERSION=1.13.1 OS=linux ARCH=amd64
wget -q -O /tmp/go${VERSION}.${OS}-${ARCH}.tar.gz https://dl.google.com/go/go${VERSION}.${OS}-${ARCH}.tar.gz
sudo tar -C /usr/local -xzf /tmp/go${VERSION}.${OS}-${ARCH}.tar.gz
rm /tmp/go${VERSION}.${OS}-${ARCH}.tar.gz

# configure environment
export GOPATH=${HOME}/go
export PATH=${PATH}:/usr/local/go/bin:${GOPATH}/bin
mkdir ${GOPATH}

cat >> ~/.bashrc <<EOF
#export GOPATH=${GOPATH}
export PATH=${PATH}
alias k=kubectl
EOF

# install singularity
SINGULARITY_REPO="https://github.com/sylabs/singularity"
git clone ${SINGULARITY_REPO} ${HOME}/singularity
cd ${HOME}/singularity && ./mconfig && cd ./builddir &&  make && sudo make install

# install singularity-cri
SINGULARITY_CRI_REPO="https://github.com/sylabs/singularity-cri"
git clone ${SINGULARITY_CRI_REPO} ${HOME}/singularity-cri
cd ${HOME}/singularity-cri && make && sudo make install

# install wlm-operator
SINGULARITY_WLM_OPERATOR_REPO="https://github.com/sylabs/wlm-operator"
git clone ${SINGULARITY_WLM_OPERATOR_REPO} ${HOME}/wlm-operator

# set up CNI config
sudo mkdir -p /etc/cni/net.d

# set up sycri service
sudo sh -c 'cat > /etc/systemd/system/sycri.service <<EOF
[Unit]
Description=Singularity-CRI
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=30
User=root
Group=root
ExecStart=${HOME}/singularity-cri/bin/sycri -v 2
EOF'
sudo systemctl start sycri
sudo systemctl status sycri

# configure crictl
sudo touch /etc/crictl.yaml
sudo chown vagrant:vagrant /etc/crictl.yaml
cat > /etc/crictl.yaml << EOF
runtime-endpoint: unix:///var/run/singularity.sock
image-endpoint: unix:///var/run/singularity.sock
timeout: 10
debug: false
EOF

export IPADDR=$(ifconfig eth1 | grep inet | awk '{print $2}'| cut -f2 -d:)
sudo -E sh -c 'cat >> /etc/systemd/system/kubelet.service.d/10-kubeadm.conf <<EOF
Environment="KUBELET_EXTRA_ARGS=--node-ip=${IPADDR}"
EOF'

sudo systemctl daemon-reload
sudo systemctl restart kubelet
