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

cat <<EOF | sudo tee /etc/systemd/network/99-default.link
[Match]
OriginalName=*
[Link]
NamePolicy=keep kernel database onboard slot path
AlternativeNamesPolicy=database onboard slot path
MACAddressPolicy=none
EOF

sudo yum install -y docker

sudo mkdir -p /usr/lib/systemd/networkd.conf.d/
cat <<EOF | sudo tee /usr/lib/systemd/networkd.conf.d/80-release.conf
# Do not clobber any routes or rules added by CNI.
[Network]
ManageForeignRoutes=no
ManageForeignRoutingPolicyRules=no
EOF
sudo systemctl restart systemd-networkd

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

sudo `aws ssm get-parameter --name kube_join_command --with-decryption --region ${region} | jq -r ".Parameter.Value"`
