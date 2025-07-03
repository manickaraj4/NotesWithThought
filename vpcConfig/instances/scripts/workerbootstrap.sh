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

sudo yum remove -y ec2-net-utils # Remove ec2-net-utils otherwise VPC CNI won't work

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

sudo yum install -y jq

arch=amd64
lscpu -J | jq '.lscpu[].data' | grep "x86_64"
if [ $? = 0 ]; then arch=amd64 ; else arch=arm64 ; fi

sudo curl -o /bin/ecr-credential-provider "https://storage.googleapis.com/k8s-staging-provider-aws/releases/v1.29.8-2-ga3014ec/linux/${arch}/ecr-credential-provider-linux-${arch}"
sudo chmod 755 /bin/ecr-credential-provider

cat <<EOF | sudo tee /etc/kubernetes/kubeletcredentialconfig.yaml
apiVersion: kubelet.config.k8s.io/v1
kind: CredentialProviderConfig
providers:
  - name: ecr-credential-provider
    apiVersion: credentialprovider.kubelet.k8s.io/v1
    matchImages:
      - "*.dkr.ecr.*.amazonaws.com"
    defaultCacheDuration: 12h
EOF

sudo systemctl enable kubelet

sudo `aws ssm get-parameter --name kube_join_command --with-decryption --region ${region} | jq -r ".Parameter.Value"`
