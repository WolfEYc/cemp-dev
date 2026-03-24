terraform {
  required_version = ">= 1.14.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  cloud {
    organization = "wolfey-code"
    workspaces {
      project = "Default Project"
      name    = "cemp_raw"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "cemp_raw" {
  bucket = "cemp-raw"
}

resource "aws_s3_bucket" "iceberg" {
  bucket = "iceberg"
}

resource "aws_s3_bucket_versioning" "iceberg" {
  bucket = aws_s3_bucket.iceberg.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_glue_catalog_database" "iceberg" {
  name = "iceberg-db"
}

resource "aws_iam_role" "glue_job_role" {
  name = "glue-iceberg-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "glue_policy" {
  name = "glue-iceberg-policy"
  role = aws_iam_role.glue_job_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 access
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.iceberg.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.iceberg.arn
      },

      # Glue catalog access
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:GetPartitions"
        ]
        Resource = "*"
      }
    ]
  })
}

output "glue_job_role_arn" {
  value = aws_iam_role.glue_job_role.arn
}

resource "aws_sqs_queue" "cemp_raw_snowpipe" {
  name                       = "cemp_raw_snowpipe"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600 # 14 days
}

resource "aws_sns_topic" "cemp_raw_snowpipe" {
  name = "cemp_raw_snowpipe"
}

resource "aws_sns_topic_policy" "cemp_raw_policy" {
  arn = aws_sns_topic.cemp_raw_snowpipe.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3Publish"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.cemp_raw_snowpipe.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.cemp_raw.arn
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "cemp_raw_sns_to_sqs" {
  topic_arn = aws_sns_topic.cemp_raw_snowpipe.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.cemp_raw_snowpipe.arn
}

data "aws_iam_policy_document" "cemp_raw_snowpipe" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["sqs:SendMessage"]

    resources = [aws_sqs_queue.cemp_raw_snowpipe.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.cemp_raw_snowpipe.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "cemp_raw_snowpipe" {
  queue_url = aws_sqs_queue.cemp_raw_snowpipe.id
  policy    = data.aws_iam_policy_document.cemp_raw_snowpipe.json
}

resource "aws_s3_bucket_notification" "cemp_raw_notify" {
  bucket = aws_s3_bucket.cemp_raw.bucket

  topic {
    topic_arn = aws_sns_topic.cemp_raw_snowpipe.arn
    events    = ["s3:ObjectCreated:*"]

    # Optional: prefix filter for only certain paths
    filter_prefix = "" # leave empty to capture all
    # filter_suffix = ".json" # optional
  }
  depends_on = [
    aws_sns_topic_subscription.cemp_raw_sns_to_sqs,
    aws_sns_topic_policy.cemp_raw_policy
  ]
}

variable "sflake_external_id" {
  type = string
}

resource "aws_iam_role" "snowflake_role" {
  name = "snowflake-storage-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "*" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = var.sflake_external_id
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "snowflake_policy" {
  name = "snowflake-iceberg-policy"
  role = aws_iam_role.snowflake_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 read (and optional write)
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.iceberg.arn,
          "${aws_s3_bucket.iceberg.arn}/*"
        ]
      },

      # Glue catalog read
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartitions"
        ]
        Resource = "*"
      }
    ]
  })
}

output "sflake_role_arn" {
  value = aws_iam_role.snowflake_role.arn
}
