output "aws_region" {
  value = var.aws_region
}

output "ecr_repository_url" {
  value = aws_ecr_repository.dbt.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "task_definition_family" {
  value = aws_ecs_task_definition.dbt.family
}

output "subnet_ids" {
  value = local.subnet_ids
}

output "security_group_id" {
  value = aws_security_group.task.id
}

output "assign_public_ip" {
  value = var.assign_public_ip ? "ENABLED" : "DISABLED"
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.dbt.name
}

output "athena_workgroup" {
  value = aws_athena_workgroup.dbt.name
}

output "glue_database" {
  value = aws_glue_catalog_database.dbt.name
}

output "s3_bucket" {
  value = aws_s3_bucket.lake.bucket
}
