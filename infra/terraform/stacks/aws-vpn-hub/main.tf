provider "aws" {
  region = var.region
}

resource "aws_vpc" "this" {
  cidr_block           = "10.255.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.255.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"
  tags                    = { Name = "${var.name}-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.name}-rt-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_key_pair" "admin" {
  key_name   = "${var.name}-key"
  public_key = file(var.ssh_pubkey_path)
}

resource "aws_security_group" "wg" {
  name        = "${var.name}-sg"
  description = "WireGuard hub"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "WireGuard"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH locked"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-sg" }
}

resource "aws_instance" "hub" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.wg.id]
  key_name                    = aws_key_pair.admin.key_name
  private_ip                  = "10.255.0.10"
  associate_public_ip_address = true

  tags = { Name = var.name }
}
