locals {
  bucket_name = "${var.project}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  athena_results_prefix = "athena-results/"
  dbt_data_prefix       = "dbt-data/"

  s3_staging_dir = "s3://${aws_s3_bucket.lake.bucket}/${local.athena_results_prefix}"
  s3_data_dir    = "s3://${aws_s3_bucket.lake.bucket}/${local.dbt_data_prefix}"
}

# One bucket for Athena query results and the table data dbt creates.
resource "aws_s3_bucket" "lake" {
  bucket        = local.bucket_name
  force_destroy = true # hello-world: allow terraform destroy with data in it
}

resource "aws_s3_bucket_public_access_block" "lake" {
  bucket                  = aws_s3_bucket.lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id

  rule {
    id     = "expire-athena-results"
    status = "Enabled"

    filter {
      prefix = local.athena_results_prefix
    }

    expiration {
      days = 7
    }
  }
}

resource "aws_glue_catalog_database" "dbt" {
  name        = var.glue_database_name
  description = "dbt models of ${var.project}"
}

resource "aws_athena_workgroup" "dbt" {
  name          = "${var.project}-dbt"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = false
    publish_cloudwatch_metrics_enabled = true

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }

    result_configuration {
      output_location = local.s3_staging_dir

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}
