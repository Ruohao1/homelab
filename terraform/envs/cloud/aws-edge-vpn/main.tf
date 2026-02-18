module "edge_vpn" {
  source = "../../../modules/aws-vpn-hub"

  name               = var.name
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  admin_cidr         = var.admin_cidr

  user_data = templatefile("${path.module}/scripts/install_wireguard.sh.tftpl", {
    wg_addr = "10.255.0.1/24"
    wg_net  = "10.255.0.0/24"
    wg_port = 51820
    wan_if  = "eth0"
  })
}
