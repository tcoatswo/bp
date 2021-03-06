# why?: deploy 3 tier app
terraform {
  backend "s3" {
    dynamodb_table = "bitpharma-tf-state-lock"
    bucket         = "bitpharma-tf-state-bucket"
    key            = "state/terraform.tfstate"
    region         = "us-east-1"
  }
}
provider "aws" {
  region = "us-east-1"
}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
variable "namespace" {
  default = "gp"
}
variable "name" {
  default = "gitpharma"
}
variable "db_master_user" {
  default = "postgres"
}
variable "db_master_pass" {} # $TF_VAR_db_master_pass -> aws-sdk/client/ssm.getParameter 
variable "stage" {
  default = "dev"
}
variable "dns_zone_id" {}
variable "instance_type" {
  default = "t3.nano"
}

module "vpc" {
  source     = "git::https://github.com/cloudposse/terraform-aws-vpc.git?ref=0.8.1"
  namespace  = var.namespace
  stage      = var.stage
  name       = "app"
  cidr_block = "10.0.0.0/16"
}
resource "aws_kms_key" "flow" {
  description             = "vpc flow log bucket encryption key"
  deletion_window_in_days = 10
}
resource "aws_s3_bucket" "flow" {
  bucket = "${var.namespace}-${var.name}-flow"
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.flow.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}
resource "aws_flow_log" "flow" {
  log_destination      = aws_s3_bucket.flow.arn
  vpc_id               = module.vpc.vpc_id
  log_destination_type = "s3"
  traffic_type         = "ALL"
}
module "subnets" {
  source             = "git::https://github.com/cloudposse/terraform-aws-dynamic-subnets.git?ref=tags/0.18.1"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  namespace          = var.namespace
  stage              = var.stage
  name               = var.name
  vpc_id             = module.vpc.vpc_id
  igw_id             = module.vpc.igw_id
  cidr_block         = module.vpc.vpc_cidr_block
  max_subnet_count   = 3
}
resource "aws_security_group" "ouroboros" {
  name   = "ouroboros-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    protocol  = -1
    from_port = 0
    to_port   = 0
    self      = true
  }
  egress {
    protocol  = -1
    from_port = 0
    to_port   = 0
    self      = true
  }
}
# aws rds describe-db-engine-versions --query "DBEngineVersions[].DBParameterGroupFamily" | grep postgresql
resource "aws_rds_cluster_parameter_group" "force_ssl" {
  name   = "database"
  family = "aurora-postgresql10"
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }
}
resource "aws_db_subnet_group" "db_subnet_group" {
  subnet_ids = module.subnets.private_subnet_ids
}
resource "aws_rds_cluster" "aurora_serverless_postgresql" {
  engine                          = "aurora-postgresql"
  engine_mode                     = "serverless"
  engine_version                  = "10.7"
  enable_http_endpoint            = false # "data api"
  db_subnet_group_name            = aws_db_subnet_group.db_subnet_group.id
  master_username                 = var.db_master_user
  master_password                 = var.db_master_pass
  final_snapshot_identifier       = "${var.namespace}-${var.name}-aurora-serverless-postgresql"
  skip_final_snapshot             = true
  vpc_security_group_ids          = [module.vpc.vpc_default_security_group_id, aws_security_group.ouroboros.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.force_ssl.name
  scaling_configuration {
    auto_pause               = true
    seconds_until_auto_pause = 300
    max_capacity             = "32"
    min_capacity             = "8"
  }
}
module "elastic_beanstalk_application" {
  source    = "git::https://github.com/cloudposse/terraform-aws-elastic-beanstalk-application.git?ref=tags/0.3.0"
  namespace = var.namespace
  stage     = var.stage
  name      = var.name
}
module "elastic_beanstalk_environment" {
  source                             = "git::https://github.com/cloudposse/terraform-aws-elastic-beanstalk-environment.git?ref=master"
  namespace                          = var.namespace
  stage                              = var.stage
  name                               = var.name
  region                             = data.aws_region.current.name
  ssh_listener_enabled               = false
  availability_zone_selector         = "Any 2"
  dns_zone_id                        = var.dns_zone_id
  dns_subdomain                      = "www"
  elastic_beanstalk_application_name = module.elastic_beanstalk_application.elastic_beanstalk_application_name
  instance_type                      = var.instance_type
  autoscale_min                      = 1
  autoscale_max                      = 8
  updating_min_in_service            = 0
  updating_max_batch                 = 1
  loadbalancer_type                  = "application"
  vpc_id                             = module.vpc.vpc_id
  loadbalancer_subnets               = module.subnets.public_subnet_ids
  application_subnets                = module.subnets.private_subnet_ids
  allowed_security_groups            = [module.vpc.vpc_default_security_group_id, aws_security_group.ouroboros.id]
  # aws elasticbeanstalk list-available-solution-stacks | grep Node
  solution_stack_name = "64bit Amazon Linux 2018.03 v4.13.0 running Node.js"
  additional_settings = [
    {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = "PGHOST"
      value     = aws_rds_cluster.aurora_serverless_postgresql.endpoint
    },
    {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = "PGUSER"
      value     = aws_rds_cluster.aurora_serverless_postgresql.master_username
    },
    {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = "PGPASSWORD"
      value     = aws_rds_cluster.aurora_serverless_postgresql.master_username
    }
  ]
}

output "db_cluster_id" {
  value = aws_rds_cluster.aurora_serverless_postgresql.id
}
output "beanstalk_app_name" {
  value = module.elastic_beanstalk_application.elastic_beanstalk_application_name
}
output "beanstalk_env_name" {
  value = module.elastic_beanstalk_environment.name
}
output "aws_region" {
  value = data.aws_region.current.name
}

