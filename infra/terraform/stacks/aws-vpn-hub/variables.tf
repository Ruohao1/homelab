variable "region" { type = string }
variable "name" {
  type    = string
  default = "wg-hub"
}

variable "ssh_pubkey_path" { type = string }
variable "admin_cidr" { type = string } # your public IP /32 for SSH, e.g. "1.2.3.4/32"

variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "ami_id" { type = string } # ubuntu 22.04 in your region (simple + explicit)
