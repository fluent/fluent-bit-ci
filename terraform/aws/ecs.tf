provider "aws" {
  region     = "us-west-2"
}

data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

locals {
  name   = "fluent-bit-ci"
  region = "us-east-1"
  user_data = <<-EOT
    #!/bin/bash
    cat <<'EOF' >> /etc/ecs/ecs.config
    ECS_CLUSTER=${local.name}
    ECS_LOGLEVEL=debug
    ECS_AVAILABLE_LOGGING_DRIVERS=["awslogs","fluentd"]
    EOF
  EOT

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Cluster  = local.name
  }
}

################################################################################
# ECS Cluster
################################################################################

module "ecs" {
  source = "terraform-aws-modules/ecs/aws"
  version = "~> 4.1"

  cluster_name = local.name
# disable cloudwatch
  cluster_settings = {
    "name": "containerInsights",
    "value": "disabled"
  }

  default_capacity_provider_use_fargate = false


  autoscaling_capacity_providers = {
    one = {
      auto_scaling_group_arn         = module.autoscaling.autoscaling_group_arn
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        maximum_scaling_step_size = 2
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 60
      }

      default_capacity_provider_strategy = {
        weight = 60
        base   = 20
      }
    }
  }

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}
# ASG with t3.micro instance type with 1 max node count
module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.5"

  name = "${local.name}-one"

  image_id      = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]
  instance_type = "t3.micro"

  security_groups                 = [module.autoscaling_sg.security_group_id]
  user_data                       = base64encode(local.user_data)
  ignore_desired_capacity_changes = true

  create_iam_instance_profile = true
  iam_role_name               = local.name
  iam_role_description        = "ECS role for ${local.name}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    CloudWatchLogsFullAccess = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  }

  vpc_zone_identifier = module.vpc.private_subnets
  health_check_type   = "EC2"
  min_size            = 0
  max_size            = 1
  desired_capacity    = 1

  # https://github.com/hashicorp/terraform-provider-aws/issues/12582
  autoscaling_group_tags = {
    AmazonECSManaged = true
  }

  # Required for  managed_termination_protection = "ENABLED"
  protect_from_scale_in = true

  tags = local.tags
}
# security group with ingress 443 only and egress all
module "autoscaling_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = local.name
  description = "Autoscaling group security group"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["https-443-tcp"]

  egress_rules = ["all-all"]

  tags = local.tags
}

# VPC for ECS cluster
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  tags = local.tags
}

# Cloudtwatch log group to collect fluent-bit container logs
resource "aws_cloudwatch_log_group" "fluent_bit_ci_lg" {
  name              = "fluent-bit-ci"
  retention_in_days = 1
}

resource "aws_ecs_task_definition" "fluent_bit_ecs" {
  family = "service"
  requires_compatibilities = ["EC2"]
  network_mode = "host"
  container_definitions = jsonencode([
    {
      name      = local.name
      image     = "celalettin1286/fluent-bit-ecs:0.1"
      cpu       = 256
      memory    = 512
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options   = {
          "awslogs-group"         = "fluent-bit-ci"
          "awslogs-region"        = "us-west-2"
          "awslogs-stream-prefix" = "fluent-bit"
        }
      }
    }
  ])
  task_role_arn = aws_iam_role.task_role.arn
}

resource "aws_ecs_service" "service" {
  name          = local.name
  cluster       = module.ecs.cluster_name
  desired_count = 1

  launch_type = "EC2"
  task_definition = aws_ecs_task_definition.fluent_bit_ecs.arn
  enable_execute_command = true
}


# task role and role policy
resource "aws_iam_role" "task_role" {
  name               = "${local.name}-ecs-task-role"
  assume_role_policy = <<POLICY
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      }
    }
  ],
  "Version": "2008-10-17"
}
POLICY
  max_session_duration = "3600"
  path                 = "/"
}

resource "aws_iam_role_policy" "task_role_policy" {
  name = "${local.name}-ecs-task-role"
  role = aws_iam_role.task_role.id

  policy = <<POLICY
{
   "Version": "2012-10-17",
   "Statement": [
       {
       "Effect": "Allow",
       "Action": [
            "ssmmessages:CreateControlChannel",
            "ssmmessages:CreateDataChannel",
            "ssmmessages:OpenControlChannel",
            "ssmmessages:OpenDataChannel",
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams"
       ],
      "Resource": "*"
      }
   ]
}
POLICY
}
