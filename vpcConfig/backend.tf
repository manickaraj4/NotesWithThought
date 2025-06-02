terraform {
  backend "s3" {
    bucket = "samplebucketfortesting12345"
    key    = "terraform/my-state.tfstate"
    region = "ap-south-1"
  }
}