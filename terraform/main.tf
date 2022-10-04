data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  region          = "us-east-1"
  db_name         = "ostock_dev"
  db_port         = 5432
  db_user         = "postgres"
  redis_port      = 6379
  myip            = chomp(data.http.myip.body)
  cluster_version = "1.23"
  cluster_name    = "ostock-dev-cluster"
  root_dir        = abspath("${path.root}/../")
}

module "vpc" {
  # https://github.com/VladRassokhin/intellij-hcl/issues/365
  source  = "registry.terraform.io/terraform-aws-modules/vpc/aws"
  version = "3.14.2"

  name = "my-smia"
  cidr = "10.0.0.0/16"

  azs                 = ["${local.region}a", "${local.region}b", "${local.region}c"]
  public_subnets      = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets    = ["10.0.111.0/24", "10.0.112.0/24", "10.0.113.0/24"]
  elasticache_subnets = ["10.0.121.0/24", "10.0.122.0/24", "10.0.123.0/24"]

  enable_nat_gateway = false

  create_database_subnet_group           = true
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = true

  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_security_group" "ostock" {
  name   = "ostock-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow-myip" {
  name   = "ostock-allow-myip-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${local.myip}/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "db" {
  source = "registry.terraform.io/terraform-aws-modules/rds/aws"

  identifier = "ostock-aws"

  create_db_instance = true

  engine            = "postgres"
  engine_version    = "13.4"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = local.db_name
  username = local.db_user
  password = var.db_password
  port     = local.db_port

  vpc_security_group_ids = [aws_security_group.ostock.id, aws_security_group.allow-myip.id]

  create_db_subnet_group = false
  db_subnet_group_name   = module.vpc.database_subnet_group_name

  publicly_accessible = true

  create_db_parameter_group = false

  skip_final_snapshot = true

  create_random_password = false
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "ostock-redis"
  engine               = "redis"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis5.0"
  # https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/supported-engine-versions.html
  engine_version       = "5.0.6"
  port                 = 6379
  subnet_group_name    = module.vpc.elasticache_subnet_group_name

  snapshot_retention_limit = 0

  security_group_ids = [aws_security_group.ostock.id]
}

