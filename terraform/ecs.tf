# --- Networking: default VPC unless told otherwise ---------------------------

data "aws_vpc" "default" {
  count   = var.vpc_id == null ? 1 : 0
  default = true
}

locals {
  vpc_id = var.vpc_id != null ? var.vpc_id : data.aws_vpc.default[0].id
}

data "aws_subnets" "selected" {
  count = length(var.subnet_ids) == 0 ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

locals {
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : data.aws_subnets.selected[0].ids
}

resource "aws_security_group" "task" {
  name        = "${var.project}-dbt-task"
  description = "dbt Fargate task: no inbound, all outbound (ECR, S3, Athena, Glue)"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Image registry -----------------------------------------------------------

resource "aws_ecr_repository" "dbt" {
  name                 = "${var.project}-dbt"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "dbt" {
  repository = aws_ecr_repository.dbt.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# --- ECS cluster and task definition -----------------------------------------

resource "aws_ecs_cluster" "this" {
  name = var.project
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

resource "aws_cloudwatch_log_group" "dbt" {
  name              = "/ecs/${var.project}-dbt"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "dbt" {
  family                   = "${var.project}-dbt"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "dbt"
    image     = "${aws_ecr_repository.dbt.repository_url}:${var.image_tag}"
    essential = true

    environment = [
      { name = "AWS_REGION", value = var.aws_region },
      { name = "AWS_DEFAULT_REGION", value = var.aws_region },
      { name = "DBT_ATHENA_SCHEMA", value = aws_glue_catalog_database.dbt.name },
      { name = "DBT_ATHENA_WORKGROUP", value = aws_athena_workgroup.dbt.name },
      { name = "DBT_ATHENA_S3_STAGING_DIR", value = local.s3_staging_dir },
      { name = "DBT_ATHENA_S3_DATA_DIR", value = local.s3_data_dir },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.dbt.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "dbt"
      }
    }
  }])
}
