resource "local_file" "private_key" {
  content         = tls_private_key.this.private_key_pem
  filename        = "${local.root_dir}/my-smia.pem"
  file_permission = "0600"
}

resource "local_file" "pg_pass" {
  content         = "${module.db.db_instance_address}:${local.db_port}:${local.db_name}:${local.db_user}:${var.db_password}"
  filename        = "${local.root_dir}/.pgpass"
  file_permission = "0600"
}

resource "local_file" "env" {
  content         = <<-EOT
  ENCRYPT_KEY = ${var.encrypt_key}
  DB_PASSWORD = ${var.db_password}
  JWT_SIGNING_KEY = ${var.jwt_signing_key}
  REGISTRY_URL = "https://${data.aws_caller_identity.current.account_id}.dkr.ecr.${local.region}.amazonaws.com/"
  DB_HOST = "${module.db.db_instance_address}"
  REDIS_HOST = "${aws_elasticache_cluster.redis.cache_nodes[0].address}"
  ES_HOST = "${module.elk2_ec2.private_dns}"
  LOGSTASH_HOST = ${module.elk2_ec2.private_dns}"
  KIBANA_HOST = "${module.elk2_ec2.private_dns}"
  ZIPKIN_HOST = "${module.elk2_ec2.private_dns}"
  EOT
  filename        = "${local.root_dir}/.env.aws"
  file_permission = "0600"
}
