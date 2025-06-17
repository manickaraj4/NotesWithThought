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

cat <<EOF | sudo tee /etc/systemd/network/99-default.link
[Match]
OriginalName=*
[Link]
NamePolicy=keep kernel database onboard slot path
AlternativeNamesPolicy=database onboard slot path
MACAddressPolicy=none
EOF

sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

sudo mkdir -p /usr/lib/systemd/networkd.conf.d/
cat <<EOF | sudo tee /usr/lib/systemd/networkd.conf.d/80-release.conf
# Do not clobber any routes or rules added by CNI.
[Network]
ManageForeignRoutes=no
ManageForeignRoutingPolicyRules=no
EOF
sudo systemctl restart systemd-networkd

sudo mkdir -p /etc/kubernetes
sudo echo "`openssl rand -hex 12`,terraform,1234,\"kubeadm:cluster-admins\"" > /etc/kubernetes/static-token

#sudo cat /etc/kubernetes/static-token | cut -d "," -f 1 > /home/ec2-user/static-token
#aws s3 cp /home/ec2-user/static-token s3://samplebucketfortesting12345/KubeConfig/static-token --content-type="text/*"
aws ssm put-parameter --name kube_static_token --value "$(sudo cat /etc/kubernetes/static-token | cut -d ',' -f 1)" --overwrite --region ${region}

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

cat <<EOF | sudo tee /etc/kubernetes/apiserver-custom.yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
apiServer:
  extraArgs:
  - name: "token-auth-file"
    value: "/etc/kubernetes/static-token"
  extraVolumes:
    - name: static-token
      hostPath: /etc/kubernetes/static-token
      mountPath: /etc/kubernetes/static-token
      readOnly: true
      pathType: "File"
EOF

sudo systemctl enable kubelet

sudo kubeadm init --config /etc/kubernetes/apiserver-custom.yaml

mkdir -p /home/ec2-user/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/ec2-user/.kube/config
sudo chown 1000:1000 /home/ec2-user/.kube/config

sudo cat /etc/kubernetes/admin.conf | grep client-key-data | cut -d ":" -f 2 | cut -d " " -f 2 | base64 -d > /home/ec2-user/.kube/client-key.pem
sudo cat /etc/kubernetes/admin.conf | grep client-certificate-data | cut -d ":" -f 2 | cut -d " " -f 2 | base64 -d > /home/ec2-user/.kube/client-cert.pem
sudo cat /etc/kubernetes/admin.conf | grep certificate-authority-data | cut -d ":" -f 2 | cut -d " " -f 2 | base64 -d > /home/ec2-user/.kube/cluster-ca-cert.pem

sleep 10

aws ssm put-parameter --name kube_join_command --value "$(sudo kubeadm token create --print-join-command)" --overwrite --region ${region}

aws s3 cp /home/ec2-user/.kube/config s3://${bucket}/KubeConfig/kubeconfig --content-type="text/*"
aws s3 cp /home/ec2-user/.kube/client-key.pem s3://${bucket}/KubeConfig/client-key.pem --content-type="text/*"
aws s3 cp /home/ec2-user/.kube/client-cert.pem s3://${bucket}/KubeConfig/client-cert.pem --content-type="text/*"
aws s3 cp /home/ec2-user/.kube/cluster-ca-cert.pem s3://${bucket}/KubeConfig/cluster-ca-cert.pem --content-type="text/*"
sudo aws s3 cp /etc/kubernetes/pki/ca.key s3://${bucket}/KubeConfig/cluster-ca-key.pem --content-type="text/*"
