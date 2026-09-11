data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_secretsmanager_secret" "grafana" {
  name                    = "${var.name}/monitoring/grafana"
  description             = "Grafana administrator password for the monitoring instance"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "grafana" {
  secret_id = aws_secretsmanager_secret.grafana.id
  secret_string = jsonencode({
    GRAFANA_ADMIN_PASSWORD = var.grafana_admin_password
  })
}

resource "aws_iam_role" "ssm" {
  name = "${var.name}-monitoring-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "grafana_secret_read" {
  name = "${var.name}-monitoring-grafana-secret-read"
  role = aws_iam_role.ssm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.grafana.arn
    }]
  })
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-monitoring-profile"
  role = aws_iam_role.ssm.name
}

resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id, var.jaeger_security_group_id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.this.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  # Bootstrap changes are delivered through the SSM association below. Avoid
  # recreating the monitoring host merely because the public latest AMI moves.
  lifecycle {
    ignore_changes = [ami]
  }

  # Windows checkouts may contain CRLF; Linux shebangs and shell commands
  # require LF. Normalize the complete rendered script before EC2/SSM use.
  user_data = replace(templatefile("${path.module}/user_data.sh", {
    application_private_ip = var.application_private_ip
    aws_region             = var.aws_region
    grafana_secret_arn     = aws_secretsmanager_secret.grafana.arn
    prometheus_image       = var.prometheus_image
    grafana_image          = var.grafana_image
    grafana_domain         = var.grafana_domain
    jaeger_image           = var.jaeger_image
  }), "\r\n", "\n")

  tags = {
    Name = "${var.name}-monitoring"
  }
}

# Applying an updated Terraform configuration to an existing monitoring EC2
# reruns the bootstrap safely without replacing its Prometheus data volume.
resource "terraform_data" "bootstrap_version" {
  input = sha256(aws_instance.this.user_data)
}

resource "aws_ssm_association" "bootstrap" {
  name                             = "AWS-RunShellScript"
  association_name                 = "${var.name}-monitoring-bootstrap"
  wait_for_success_timeout_seconds = 300

  targets {
    key    = "InstanceIds"
    values = [aws_instance.this.id]
  }

  parameters = {
    commands = aws_instance.this.user_data
  }

  depends_on = [
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy.grafana_secret_read
  ]

  # The provider waits for execution success on creation, not on updates.
  # Replace on script changes so bootstrap failures are reported by apply.
  lifecycle {
    replace_triggered_by = [terraform_data.bootstrap_version]
  }
}
