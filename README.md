# NotesWithThought

A self-managed kuberentes cluster with minimal footprint on AWS. Designed to be run on low cost (Using free tier as much as possible).
`Note: Some services used might incur cost.`

Still in progress....

### Prerequisities:

- AWS Account (with Free tier)
- A Domain Registered

##### Additional Manual Steps

1. An User for deployment.
2. A S3 bucket that will hold all the objects related to deployment.
3. Secrets/Parameters on SSM as and when required.
4. SSH Key for access

## Steps to deploy:

1. Export the session keys for user/Role on CLI
2. Install terraform and deploy after populating variables for Bucket name, SSH key, AWS region, Domain on vars.tf.
```
cd vpcConfig
terraform init 
terraform plan
terraform apply
```
3. Deploy the kubernetes objects again.
```
cd kubeObjects
terraform init 
terraform plan
terraform apply
```
### General Notes: 
- Some components might have interdepency on deployed components. Comment out the resources that are creating problems and deploy again afterwards.
- Domain update API is using space ship. You can use your own vender APIs
- CNI tested are flannel and VPC-CNI.
- Jenkins is installed via helm and exposed on sub-domain `jenkins`
- Grafana is installed via helm and exposed on sub-domaina `grafana`
- IRSA is implemented so we can exchange service account tokens for AWS credentials. Kuberenetes API server is exposed on sub-domain `kubadmin`.
- Nginx is used for Ingress and NLB is used as Loadbalancer to accept public traffic.
- Contains a sample note taking application deployment based on Go and React - Provides Oauth authentication.
- Used RDS as database



