#!/bin/bash
sudo yum update

sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

cat <<EOF | sudo tee /etc/sysctl.conf 
net.ipv4.ip_forward = 1
EOF

sudo sysctl -p

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

sudo yum install yum-utils device-mapper-persistent-data lvm2 containerd -y
sudo yum install -y docker

sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

cat <<EOF | sudo tee /etc/containerd/config.toml
version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
   [plugins."io.containerd.grpc.v1.cri".containerd]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
EOF

sudo systemctl enable --now docker

sudo systemctl enable kubelet
sudo kubeadm init

mkdir -p /home/ec2-user/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/ec2-user/.kube/config
sudo chown 1000:1000 /home/ec2-user/.kube/config

sudo cat /etc/kubernetes/admin.conf | grep client-key-data | cut -d ":" -f 2 | cut -d " " -f 2 | base64 -d > /home/ec2-user/.kube/client-key.pem
sudo cat /etc/kubernetes/admin.conf | grep client-certificate-data | cut -d ":" -f 2 | cut -d " " -f 2 | base64 -d > /home/ec2-user/.kube/client-cert.pem
sudo cat /etc/kubernetes/admin.conf | grep certificate-authority-data | cut -d ":" -f 2 | cut -d " " -f 2 | base64 -d > /home/ec2-user/.kube/cluster-ca-cert.pem

sleep 10

#kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/refs/heads/master/manifests/calico.yaml

aws ssm put-parameter --name kube_join_command --value "$(sudo kubeadm token create --print-join-command)" --overwrite --region ap-south-1 

aws s3 cp /home/ec2-user/.kube/config s3://samplebucketfortesting12345/KubeConfig/kubeconfig
aws s3 cp /home/ec2-user/.kube/config s3://samplebucketfortesting12345/KubeConfig/client-key.pem
aws s3 cp /home/ec2-user/.kube/config s3://samplebucketfortesting12345/KubeConfig/client-cert.pem
aws s3 cp /home/ec2-user/.kube/config s3://samplebucketfortesting12345/KubeConfig/cluster-ca-cert.pem
