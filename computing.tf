data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "example" {
  key_name   = "example-key"
  public_key = tls_private_key.example.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.example.private_key_pem
  filename        = "${path.module}/example-key.pem"
  file_permission = "0400"
}

resource "aws_eip" "eip" {
  instance = aws_instance.public_instance.id
}

resource "aws_instance" "public_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet[0].id
  private_ip    = cidrhost(aws_subnet.subnet[0].cidr_block, 10)
  key_name      = aws_key_pair.example.key_name
  security_groups = [
    aws_security_group.public_instance_sg.id,
  ]

  user_data = <<-EOF
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install apache2 -y
    sudo systemctl start apache2
    sudo systemctl enable apache2
  EOF

  tags = {
    Name = "public-instance"
  }
}

resource "aws_instance" "private_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet[1].id
  private_ip    = cidrhost(aws_subnet.subnet[1].cidr_block, 10)
  key_name      = aws_key_pair.example.key_name
  security_groups = [
    aws_security_group.private_instance_sg.id,
  ]

  user_data = <<-EOF
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install mysql-server -y
    sudo systemctl start mysql
    sudo systemctl enable mysql
  EOF

  tags = {
    Name = "db-instance"
  }
}

locals {
  public_ingress_rules = [
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { from_port = -1, to_port = -1, protocol = "icmp", cidr_blocks = ["0.0.0.0/0"] }
  ]
  private_ingress_rules = [
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = [aws_subnet.subnet[0].cidr_block] },
    { from_port = 3306, to_port = 3306, protocol = "tcp", cidr_blocks = [aws_subnet.subnet[0].cidr_block] },
    { from_port = -1, to_port = -1, protocol = "icmp", cidr_blocks = [aws_subnet.subnet[0].cidr_block] }
  ]
  all_egress_rule = [
    { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
  ]
}


resource "aws_security_group" "public_instance_sg" {
  vpc_id = aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = local.public_ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = local.all_egress_rule
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

}

resource "aws_security_group" "private_instance_sg" {
  vpc_id = aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = local.private_ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = local.all_egress_rule
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }
}
