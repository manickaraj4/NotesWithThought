#!/bin/bash

yum install tar -y
mkdir -p /mnt/ui

aws s3 cp s3://${S3_BUCKET}/postsapp/buildfiles/app /mnt/
aws s3 cp s3://${S3_BUCKET}/postsapp/buildfiles/build.tar.gz /mnt/ui/

cd /mnt/ui 
tar -xvf build.tar.gz

sleep 30d
