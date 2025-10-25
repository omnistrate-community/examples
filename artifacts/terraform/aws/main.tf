provider "aws" {
  region = "{{ $sys.deploymentCell.region }}"
}

locals {
  region = "{{ $sys.deploymentCell.region }}"
  availability_zones = [
    "${local.region}a",
    "${local.region}b",
    "${local.region}d"
  ]
  vpc_id = "{{ $sys.deploymentCell.cloudProviderNetworkID }}"
  subnet_ids = [
    "{{ $sys.deploymentCell.publicSubnetIDs[0].id }}",
    "{{ $sys.deploymentCell.publicSubnetIDs[1].id }}",
    "{{ $sys.deploymentCell.publicSubnetIDs[2].id }}"
  ]

  s3_bucket_name = "some-bucket-name-new-test"
}

# S3 Bucket
module "db_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.1.1"

  bucket = local.s3_bucket_name

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


output "bucket_url_update" {
  value = {
    arn: module.db_bucket.s3_bucket_arn
  }
  sensitive = true
}