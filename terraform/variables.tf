variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "eu-central-1"
}

variable "project" {
  description = "Name prefix for all resources."
  type        = string
  default     = "air-one"
}

variable "glue_database_name" {
  description = "Glue / Athena database (the dbt schema) the models are written to."
  type        = string
  default     = "air_one"
}

variable "image_tag" {
  description = "Tag of the dbt image in ECR that the task definition runs."
  type        = string
  default     = "latest"
}

variable "task_cpu" {
  description = "Fargate CPU units (256 = 0.25 vCPU)."
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Fargate memory in MiB."
  type        = number
  default     = 1024
}

variable "vpc_id" {
  description = "VPC to run the task in. Leave null to use the account's default VPC."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Subnets for the task. Leave empty to use all subnets of the VPC. They need a route to the internet (public subnet + public IP, or a NAT gateway) or VPC endpoints for ECR, S3, Athena, Glue, STS and CloudWatch Logs."
  type        = list(string)
  default     = []
}

variable "assign_public_ip" {
  description = "Give the task a public IP. Needed in public subnets without NAT so it can reach ECR and the AWS APIs."
  type        = bool
  default     = true
}
