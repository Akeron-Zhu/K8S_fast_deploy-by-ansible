#!/bin/bash

for i in $(cat ./hosts )
do
    echo $i
	#取出ip和密码
	HN=$(echo "${i}" |awk -F":" '{print $1}')
	USER=$(echo "${i}" |awk -F":" '{print $2}')
	IP=$(echo "${i}" |awk -F":" '{print $3}')
	PW=$(echo "${i}" |awk -F":" '{print $4}')
	ROLE=$(echo "${i}" |awk -F":" '{print $5}'|awk 'BEGIN{RS=","} {print $0}')
    #ssh $USER@$IP 'rm -r ~/.ssh/*'
    ssh $USER@$IP 'kubectl delete -f /root/kube-flannel.yml'
	ssh $USER@$IP 'kubectl delete -f /root/nginx-ingress.yml'
    ssh $USER@$IP 'expect -c "
        spawn kubeadm reset
        expect \":\"
        send \"y\r\"
        expect eof"'
    ssh $USER@$IP 'rm -r /etc/kubernetes/*'
    ssh $USER@$IP 'rm -r /var/lib/etcd'
    ssh $USER@$IP 'rm -r ~/.kube'
    ssh $USER@$IP 'docker kill $(docker ps -a -q)'
    ssh $USER@$IP 'docker rm $(docker ps -a -q)'
    ssh $USER@$IP 'docker rmi -f $(docker images -q)'
    ssh $USER@$IP 'rm /etc/sysctl.d/k8s.conf '   
    ssh $USER@$IP 'rm -r /root/ntp /root/docker-ce'
    for role in $ROLE
	do
		if [ "$role"x == "ntpd"x ];then
			echo "ntpd"
		elif [ "$role"x == "registry"x ];then
            ssh $USER@$IP 'rm -r /root/registry'
		elif [ "$role"x == "master"x ];then
            ssh $USER@$IP 'rm -r /root/kube'
			#echo -e "\nToken=$TOKEN\n"
		elif [ "$role"x == "node"x ];then
            ssh $USER@$IP 'rm -r /root/kube'
		fi
	done 
    
done

