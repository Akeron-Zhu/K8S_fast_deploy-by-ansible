swapoff -a
kubeadm init \
--apiserver-advertise-address=$1 \
--image-repository chinatelecom.hub.com:5000 \
--kubernetes-version v1.19.4 \
--service-cidr=10.24.0.0/16 \
--pod-network-cidr=10.244.0.0/16

cd ~
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
