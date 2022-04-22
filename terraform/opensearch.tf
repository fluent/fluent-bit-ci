locals {
  opensearch_domain_name = "calyptia-opensearch"
}

resource "aws_cloudwatch_log_group" "log_group" {
  name              = "/calyptia/opensearch"
  retention_in_days = 30
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_elasticsearch_domain" "opensearch" {
  domain_name           = local.opensearch_domain_name
  elasticsearch_version = var.opensearch_version

  access_policies = jsonencode(
    {
      "Version" = "2012-10-17"
      "Statement" = [
        {
          "Action" = "es:*"
          "Effect" = "Allow"
          "Principal" = {
            "AWS" = "*"
          }
          "Resource" = "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${local.opensearch_domain_name}/*"
        }
      ]
    }
  )
  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = var.opensearch_master_user_name
      master_user_password = var.opensearch_admin_password
    }
  }

  cluster_config {
    instance_type            = var.opensearch_instance_type
    instance_count           = var.opensearch_instance_count
    dedicated_master_enabled = true
    dedicated_master_type    = var.opensearch_dedicated_master_type
    dedicated_master_count   = var.opensearch_master_node_count
    warm_enabled             = false
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-0-2019-07"
  }

  node_to_node_encryption {
    enabled = true
  }

  ebs_options {
    ebs_enabled = true
    volume_size = var.opensearch_volume_size
  }

  encrypt_at_rest {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  # Publish application logs to cloudwatch.
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.log_group.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

}

# Policy to allow OpenSearch service to publish cloudwatch logs.
resource "aws_cloudwatch_log_resource_policy" "opensearch" {
  policy_name = "opensearch"

  policy_document = <<CONFIG
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "es.amazonaws.com"
      },
      "Action": [
        "logs:PutLogEvents",
        "logs:PutLogEventsBatch",
        "logs:CreateLogStream"
      ],
      "Resource": "arn:aws:logs:*"
    }
  ]
}
CONFIG
}

output "aws-opensearch-endpoint" {
  description = "Domain-specific endpoint used to submit index, search, and data upload requests"
  value       = aws_elasticsearch_domain.opensearch.endpoint
}