resource "aws_iam_role" "investment_app" {
  name = "investment-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "investment_app" {
  name = "investment-app-profile"
  role = aws_iam_role.investment_app.name
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "investment_app_secrets" {
  name = "read-investment-app-secrets"
  role = aws_iam_role.investment_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "secretsmanager:GetSecretValue"
        Resource = [
          "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:investment-app/finnhub-key-*",
          "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:investment-app/db-password-*"
        ]
      }
    ]
  })
}