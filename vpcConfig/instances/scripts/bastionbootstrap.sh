#!/bin/bash
sudo yum update

sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

cat <<EOF | sudo tee /etc/sysctl.conf 
net.ipv4.ip_forward = 1
net.ipv4.tcp_keepalive_intvl = 30
EOF

sudo sysctl -p

sudo yum install yum-utils device-mapper-persistent-data lvm2 containerd -y
sudo yum install -y docker

sudo systemctl enable --now docker

