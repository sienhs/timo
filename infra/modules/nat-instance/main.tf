data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_security_group" "this" {
  name        = "${var.name}-nat-sg"
  description = "Allow routed traffic from the private application subnet"
  vpc_id      = var.vpc_id

  ingress {
    description = "Forward traffic from private application subnet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.private_app_subnet_cidr]
  }

  egress {
    description = "NAT outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-nat-sg"
  }
}

resource "aws_iam_role" "ssm" {
  name = "${var.name}-nat-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-nat-profile"
  role = aws_iam_role.ssm.name
}

resource "aws_instance" "this" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]

  # A NAT instance must forward packets whose source/destination is not itself.
  source_dest_check = false

  # Required during first boot so user_data can install iptables-services.
  # The EIP below replaces this temporary public IPv4 after association.
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.this.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  # Keep the NAT instance on its current AMI until an explicit maintenance
  # replacement. The latest-AMI SSM parameter must not cause surprise outages.
  lifecycle {
    ignore_changes = [ami]
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    private_app_subnet_cidr = var.private_app_subnet_cidr
  })

  # user_data runs at instance creation. Recreate the NAT EC2 if its
  # bootstrap logic changes so the new configuration is guaranteed to apply.
  user_data_replace_on_change = true

  tags = {
    Name = "${var.name}-nat"
  }
}

resource "aws_eip" "this" {
  domain = "vpc"

  tags = {
    Name = "${var.name}-nat-eip"
  }
}

resource "aws_eip_association" "this" {
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this.id
}

resource "aws_route" "private_internet" {
  route_table_id         = var.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"

  # Current AWS provider route resources prefer the EC2 network interface
  # rather than the deprecated instance_id route target argument.
  network_interface_id = aws_instance.this.primary_network_interface_id
}
