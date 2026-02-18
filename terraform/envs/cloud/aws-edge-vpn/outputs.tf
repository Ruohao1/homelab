output "public_ip" {
  description = "Public IP address of the VPN gateway"
  value       = module.edge_vpn.public_ip
}

output "instance_id" {
  description = "EC2 instance ID for the VPN gateway"
  value       = module.edge_vpn.instance_id
}

output "vpc_id" {
  description = "VPC ID for the VPN gateway stack"
  value       = module.edge_vpn.vpc_id
}

output "public_subnet_id" {
  description = "Public subnet ID for the VPN gateway"
  value       = module.edge_vpn.public_subnet_id
}

output "security_group_id" {
  description = "Security group ID for the VPN gateway"
  value       = module.edge_vpn.security_group_id
}
