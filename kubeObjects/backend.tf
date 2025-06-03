terraform {
  backend "s3" {
    bucket = "samplebucketfortesting12345"
    key    = "terraform/kubeobj.tfstate"
    region = "ap-south-1"
  }
}