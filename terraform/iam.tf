data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# --- Execution role: lets ECS pull the image and write logs ---------------

resource "aws_iam_role" "execution" {
  name               = "${var.project}-dbt-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- Task role: what dbt itself may do --------------------------------------

resource "aws_iam_role" "task" {
  name               = "${var.project}-dbt-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

locals {
  arn_prefix   = "arn:${data.aws_partition.current.partition}"
  region_acct  = "${var.aws_region}:${data.aws_caller_identity.current.account_id}"
  glue_catalog = "${local.arn_prefix}:glue:${local.region_acct}:catalog"
}

data "aws_iam_policy_document" "task" {
  statement {
    sid = "Athena"
    actions = [
      "athena:StartQueryExecution",
      "athena:StopQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:GetWorkGroup",
    ]
    resources = [aws_athena_workgroup.dbt.arn]
  }

  statement {
    sid = "AthenaCatalog"
    actions = [
      "athena:ListWorkGroups",
      "athena:GetDataCatalog",
      "athena:ListDataCatalogs",
      "athena:ListDatabases",
      "athena:GetDatabase",
      "athena:ListTableMetadata",
      "athena:GetTableMetadata",
    ]
    resources = ["*"]
  }

  statement {
    sid = "GlueRead"
    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:GetTableVersions",
    ]
    resources = [
      local.glue_catalog,
      "${local.arn_prefix}:glue:${local.region_acct}:database/*",
      "${local.arn_prefix}:glue:${local.region_acct}:table/*/*",
    ]
  }

  statement {
    sid = "GlueWriteOwnDatabase"
    actions = [
      "glue:CreateDatabase",
      "glue:UpdateDatabase",
      "glue:CreateTable",
      "glue:UpdateTable",
      "glue:DeleteTable",
      "glue:BatchDeleteTable",
      "glue:CreatePartition",
      "glue:BatchCreatePartition",
      "glue:UpdatePartition",
      "glue:DeletePartition",
      "glue:BatchDeletePartition",
      "glue:DeleteTableVersion",
      "glue:BatchDeleteTableVersion",
    ]
    resources = [
      local.glue_catalog,
      "${local.arn_prefix}:glue:${local.region_acct}:database/${var.glue_database_name}",
      "${local.arn_prefix}:glue:${local.region_acct}:table/${var.glue_database_name}/*",
    ]
  }

  statement {
    sid       = "S3Bucket"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:ListBucketMultipartUploads"]
    resources = [aws_s3_bucket.lake.arn]
  }

  statement {
    sid = "S3Objects"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = ["${aws_s3_bucket.lake.arn}/*"]
  }

  # Only needed if Lake Formation governs the catalog; harmless otherwise.
  statement {
    sid       = "LakeFormation"
    actions   = ["lakeformation:GetDataAccess"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task" {
  name   = "dbt-athena"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task.json
}
