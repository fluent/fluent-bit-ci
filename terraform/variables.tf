variable "aws_region" {
  type        = string
  description = "Default AWS region to use"
  default     = "us-east-1"
}

variable "aws_access_id" {
  type        = string
  description = "AWS access ID"
  sensitive = true
}

variable "aws_secret_key" {
  type        = string
  description = "AWS secret key"
  sensitive = true
}

variable "opensearch_master_user_name" {
  type        = string
  description = "Master username for OpenSearch"
  default     = "admin"
  sensitive = true
}

variable "opensearch_admin_password" {
  type        = string
  description = "Master password for OpenSearch"
  sensitive = true
}

variable "opensearch_instance_type" {
  type        = string
  description = "Instance type for OpenSearch data nodes"
  default     = "m5.large.elasticsearch"
}

variable "opensearch_dedicated_master_type" {
  type        = string
  description = "Instance type for OpenSearch master nodes"
  default     = "m5.large.elasticsearch"
}

variable "opensearch_master_node_count" {
  type        = number
  description = "Dedicated master node count for OpenSearch - must be correct number of nodes for master election"
  default     = 3
}

variable "opensearch_instance_count" {
  type        = number
  description = "Data node count for OpenSearch"
  default     = 3
}

variable "opensearch_volume_size" {
  type        = number
  description = "Dedicated EBS volume size for nodes"
  default     = 10
}

variable "opensearch_version" {
  type        = string
  description = "OpenSearch version"
  default     = "OpenSearch_1.2"
}