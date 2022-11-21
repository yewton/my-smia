data "aws_ssm_parameter" "al2_latest" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-kernel-5.10-hvm-x86_64-gp2"
}

module "elkz_ec2" {
  source  = "registry.terraform.io/terraform-aws-modules/ec2-instance/aws"
  version = "~> 4.1.4"

  name = "elkz"

  # spot_price 未指定でオンデマンド価格が最大になる
  create_spot_instance = true
  spot_type            = "persistent"

  ami                    = data.aws_ssm_parameter.al2_latest.value
  instance_type          = "m4.large"
  key_name               = module.key_pair.key_pair_name
  vpc_security_group_ids = [aws_security_group.ostock.id, aws_security_group.allow-myip.id]
  subnet_id              = module.vpc.public_subnets[0]

  user_data = file("cloud-init-elk.yml")
}
