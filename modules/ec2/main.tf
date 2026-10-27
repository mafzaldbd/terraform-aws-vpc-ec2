data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------- Secrets ----------
resource "random_password" "api_key" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "api_key" {
  name                    = "${var.project}-api-key"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id     = aws_secretsmanager_secret.api_key.id
  secret_string = random_password.api_key.result
}

# ---------- IAM role for the instance ----------
resource "aws_iam_role" "web" {
  name = "${var.project}-web-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "secrets" {
  name = "read-app-secrets"
  role = aws_iam_role.web.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = [var.db_secret_arn, aws_secretsmanager_secret.api_key.arn]
    }]
  })
}

resource "aws_iam_instance_profile" "web" {
  name = "${var.project}-web-profile"
  role = aws_iam_role.web.name
}

# ---------- Network and instance ----------
resource "aws_security_group" "web" {
  name        = "${var.project}-web-sg"
  description = "Allow HTTP"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-web-sg" }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.web.name

  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    set -eo pipefail
    dnf install -y docker jq
    systemctl enable --now docker

    REGION=ap-south-1
    IMAGE=${var.ecr_repository_url}:latest
    REGISTRY=$(echo "$IMAGE" | cut -d/ -f1)
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REGISTRY

    DB_SECRET=$(aws secretsmanager get-secret-value --region $REGION --secret-id ${var.db_secret_arn} --query SecretString --output text)
    DB_USER=$(echo "$DB_SECRET" | jq -r .username)
    DB_PASS=$(echo "$DB_SECRET" | jq -r '.password | @uri')
    API_KEY=$(aws secretsmanager get-secret-value --region $REGION --secret-id ${aws_secretsmanager_secret.api_key.arn} --query SecretString --output text)

    DATABASE_URL="postgresql://$DB_USER:$DB_PASS@${var.db_endpoint}/${var.db_name}?sslmode=require"

    docker pull $IMAGE
    docker run --rm -e DATABASE_URL="$DATABASE_URL" -e API_KEY="$API_KEY" $IMAGE python create_tables.py
    docker run -d --name incident-tracker --restart unless-stopped -p 80:8000 \
      -e DATABASE_URL="$DATABASE_URL" -e API_KEY="$API_KEY" $IMAGE
  EOF

  tags = { Name = "${var.project}-web" }
}