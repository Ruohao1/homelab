resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "vpc-${var.name}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "igw-${var.name}"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = { Name = "subnet-${var.name}-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = { Name = "rt-${var.name}-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


resource "aws_security_group" "edge_vpn" {
  name        = "${var.name}-edge-vpn"
  description = "Edge WireGuard gateway"
  vpc_id      = aws_vpc.this.id

  tags = { Name = "sg-${var.name}-edge-vpn" }
}

resource "aws_vpc_security_group_ingress_rule" "wg_udp" {
  security_group_id = aws_security_group.edge_vpn.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "udp"
  from_port         = 51820
  to_port           = 51820
}

resource "aws_vpc_security_group_ingress_rule" "ssh_admin" {
  security_group_id = aws_security_group.edge_vpn.id
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.edge_vpn.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

data "aws_ami" "debian" {
  most_recent = true
  owners      = ["136693071363"] # Debian official

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_eip" "gw" {
  domain = "vpc"
  tags   = { Name = "eip-${var.name}-edge-vpn" }
}

resource "aws_instance" "gw" {
  ami                         = data.aws_ami.debian.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.edge_vpn.id]
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  user_data = var.user_data

  tags = {
    Name = "gw-${var.name}-01"
  }
}
resource "aws_eip_association" "gw" {
  instance_id   = aws_instance.gw.id
  allocation_id = aws_eip.gw.id
}
