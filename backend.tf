terraform {
  backend "s3" {
    bucket         = "vendorcorp-platform-core"
    key            = "terraform-state/tools-jenkins"
    dynamodb_table = "vendorcorp-terraform-state-lock"
    region         = "us-east-2"
  }
}
