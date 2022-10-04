output "ecr_repo_urls" {
  value = [for k, v in module.ecr : { name = k, url = v.repository_url }]
}

output "elkz_public_ip" {
  value = module.elk2_ec2.public_ip
}

output "eks_node_public_ip" {
  value = data.aws_instance.eks_managed.public_ip
}

output "psql_args" {
  value = "-h ${module.db.db_instance_address} -p ${local.db_port} -U ${local.db_user} ${local.db_name}"
}
