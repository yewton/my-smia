output "elkz_public_ip" {
  value = module.elkz_ec2.public_ip
}

output "eks_node_public_ip" {
  value = data.aws_instance.eks_managed.public_ip
}
