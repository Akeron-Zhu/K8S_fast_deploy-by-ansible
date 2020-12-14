# close firewall
# close selinux
# close swap. Remeber to modify the /etc/fstab file.
# Set the hostname

NTPD_SERVER="192.168.1.1"
TOKEN=""
SHA=""
for i in $(cat ./hosts )
do
	echo $i
	#取出ip和密码
	HN=$(echo "${i}" |awk -F":" '{print $1}')
	USER=$(echo "${i}" |awk -F":" '{print $2}')
	IP=$(echo "${i}" |awk -F":" '{print $3}')
	PW=$(echo "${i}" |awk -F":" '{print $4}')
	ROLE=$(echo "${i}" |awk -F":" '{print $5}'|awk 'BEGIN{RS=","} {print $0}')
	ssh $USER@$IP bash -c "'hostnamectl set-hostname $HN'"
	scp -rq ntp/ $USER@$IP:/root/
	scp -rq docker-ce/ $USER@$IP:/root/
	ssh $USER@$IP 'systemctl stop firewalld'
	ssh $USER@$IP 'systemctl disable firewalld'
	ssh $USER@$IP "sed -i 's/enforcing/disabled/' /etc/selinux/config"
	ssh $USER@$IP 'setenforce 0; swapoff -a'
	ssh $USER@$IP 'rpm -Uvh /root/ntp/*.rpm'
	ssh $USER@$IP 'rpm -Uvh /root/docker-ce/*.rpm'
	ssh $USER@$IP 'mkdir -p /etc/docker/certs.d/chinatelecom.hub.com:5000/'
	scp ./registry/certs/domain.crt $USER@$IP:/etc/docker/certs.d/chinatelecom.hub.com:5000/ca.crt
	ssh $USER@$IP 'systemctl enable docker && systemctl start docker'
	ssh $USER@$IP 'echo -e "net.bridge.bridge-nf-call-ip6tables=1\nnet.bridge.bridge-nf-call-iptables=1" > /etc/sysctl.d/k8s.conf' #-e 开启转义
	ssh $USER@$IP 'echo 1 > /proc/sys/net/ipv4/ip_forward'
	for role in $ROLE
	do
		if [ "$role"x == "ntpd"x ];then
			scp ./ntp/ntp.conf $USER@$IP:/etc/ntp.conf
			ssh $USER@$IP 'service ntpd start'
			NTPD_SERVER=$IP
			echo $NTPD_SERVER
		elif [ "$role"x == "registry"x ];then
			scp -rq ./registry $USER@$IP:/root/
			ssh $USER@$IP 'docker load < /root/registry/registry.tar.gz'
			ssh $USER@$IP 'docker run -d -p 5000:5000 -v /root/registry/reg/:/var/lib/registry -v /root/registry/certs:/certs -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key registry:2 '
		elif [ "$role"x == "master"x ];then
			ssh $USER@$IP bash -c "'ntpdate $NTPD_SERVER'"
			scp -rq kube $USER@$IP:/root/
			ssh $USER@$IP 'rpm -Uvh /root/kube/*.rpm'
			ssh $USER@$IP 'systemctl enable kubelet'
			ssh $USER@$IP /root/kube/master_init.sh $IP
			TOKEN=$(ssh $USER@$IP "kubeadm token list |tail -n 1|cut -d ' ' -f 1")
			SHA=$(ssh $USER@$IP "openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'")
			ssh $USER@$IP 'kubectl apply -f /root/kube/kube-flannel.yml'
			ssh $USER@$IP 'kubectl apply -f /root/kube/ingress-nginx.yml'
			#echo -e "\nToken=$TOKEN\n"
		elif [ "$role"x == "node"x ];then
			#echo $NTPD_SERVER
			ssh $USER@$IP bash -c "'ntpdate $NTPD_SERVER'"
			scp -rq kube $USER@$IP:/root/
			ssh $USER@$IP 'rpm -Uvh /root/kube/*.rpm' 
			ssh $USER@$IP 'systemctl enable kubelet' 
			ssh $USER@$IP bash -c "'kubeadm join master:6443 --token $TOKEN --discovery-token-ca-cert-hash sha256:$SHA'"
		fi
	done
	echo -e '\n\n'
done
sysctl --system
# Sync time
