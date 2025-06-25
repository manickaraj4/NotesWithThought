# NotesWithThought

A k8s cluster with minimal footprint on AWS. Designed to be run on low cost (Using free tier)

## Steps to deploy:

1. Get a AWS account and export the session keys for user/Role on CLI
2. Install terraform 
3. Create a S3 Bucket for storing state file and other stuff and note down the name.
4. Run initialize terraform with `config_s3_bucket` variable for infrastructure:
```
cd vpcConfig
terraform init 
terraform plan
terraform apply
```
5. Note down the Loadbalancer DNS on the output and initialize terraform with `apiserver_host` variable for deploying kubernetes objects:
```
cd kubeObjects
terraform init 
terraform plan
terraform apply
```
### Notes
- You can change the aws region and bucket as required.


