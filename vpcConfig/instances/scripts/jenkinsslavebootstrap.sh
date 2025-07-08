#!/bin/bash
sudo yum update

sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

sudo yum install -y git 
sudo yum install yum-utils device-mapper-persistent-data lvm2 containerd -y
sudo yum install -y docker
sudo systemctl enable --now docker

sudo groupadd docker
sudo usermod -aG docker ec2-user

curl -fL -o corretto.rpm https://corretto.aws/downloads/latest/amazon-corretto-21-x64-linux-jdk.rpm
sudo yum localinstall -y corretto.rpm
sudo yum install -y jq

sudo dd if=/dev/zero of=/swapfile bs=128M count=16
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
sudo swapon -s
echo "/swapfile swap swap defaults 0 0" | sudo tee -a /etc/fstab

export JAVA_HOME=/usr/lib/jvm/java-21-amazon-corretto
