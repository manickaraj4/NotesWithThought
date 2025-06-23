/* resource "aws_ecr_repository" "app_repo" {
  name                 = "apprepo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_pull_through_cache_rule" "eks_image_cache" {
  ecr_repository_prefix      = "ecr-public-eks"
  upstream_registry_url      = "public.ecr.aws"
  #upstream_repository_prefix = "eks"
} */