#!/bin/bash

#Данный скрипт производит автоматическую настройку k8s версии 1.26.8 и containerd
#Скрипт сможет поставить k8s с версии 1.26.0 и до 1.26.8 было протестировано. Не забудьте только заменить значения на строке 38
echo "deb https://deb.debian.org/debian/               buster         main contrib non-free" >> /etc/apt/sources.list
echo "deb https://security.debian.org/debian-security/ buster/updates main contrib non-free" >> /etc/apt/sources.list
echo "deb https://archive.debian.org/debian/ stretch main contrib non-free" >> /etc/apt/sources.list
apt update
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 112695A0E562B32A
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 54404762BBB6E853
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 648ACFD622F3D138
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0E98404D386FA1D9
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys DCC9EFBF77E11517
apt update
apt install -y curl gnupg software-properties-common apt-transport-https ca-certificates curl wget gnupg vim nano git -y
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
echo -e "net.bridge.bridge-nf-call-ip6tables = 1\nnet.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1" > /etc/modules-load.d/containerd.conf
sysctl -f /etc/modules-load.d/containerd.conf
echo -e "net.bridge.bridge-nf-call-ip6tables = 1\nnet.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1" > /etc/sysctl.d/kubernetes.conf
sysctl -f /etc/sysctl.d/kubernetes.conf
modprobe overlay
modprobe br_netfilter
sysctl --system
curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
echo "deb [arch=amd64] https://download.docker.com/linux/debian buster stable" | tee -a /etc/apt/sources.list
apt update
apt install -y containerd.io
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add
cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt update
export version=1.26.0-00
apt install curl wget kubelet=$version kubeadm=$version kubectl=$version -y
apt-mark hold kubelet kubeadm kubectl
#crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock version
#crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock --set image-endpoint=unix:///run/containerd/containerd.sock
kubeadm config images pull
kubeadm init --pod-network-cidr=10.244.0.0/16
wget https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/calico.yaml
wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.7.1/deploy/static/provider/do/deploy.yaml
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" > /etc/environment
export KUBECONFIG=/etc/kubernetes/admin.conf
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
kubectl create namespace ingress-nginx
kubectl apply -f calico.yaml
kubectl apply -f deploy.yaml --namespace=ingress-nginx
kubectl taint nodes --all node-role.kubernetes.io/control-plane-