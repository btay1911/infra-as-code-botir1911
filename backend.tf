terraform {
  backend "s3" {
    bucket         = "infra-as-code-botir1911"
    key            = "unit1/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}