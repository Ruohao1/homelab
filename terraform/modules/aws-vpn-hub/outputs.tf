output "public_ip" {
  description = "Public IP address of the VPN gateway"
  value       = aws_eip.gw.public_ip
}

output "instance_id" {
  description = "EC2 instance ID for the VPN gateway"
  value       = aws_instance.gw.id
}

output "vpc_id" {
  description = "VPC ID for the VPN gateway stack"
  value       = aws_vpc.this.id
}

output "public_subnet_id" {
  description = "Public subnet ID for the VPN gateway"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "Security group ID for the VPN gateway"
  value       = aws_security_group.edge_vpn.id
}
