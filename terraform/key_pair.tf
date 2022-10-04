resource "tls_private_key" "this" {
  algorithm = "RSA"
}

module "key_pair" {
  source  = "registry.terraform.io/terraform-aws-modules/key-pair/aws"
  version = "~> 2.0"

  key_name   = "my-smia"
  public_key = tls_private_key.this.public_key_openssh
}
