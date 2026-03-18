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
      project = "cemp_land"
      name    = "cemp_raw"
    }
  }
}

resource "aws_s3_bucket" "cemp_raw" {
  bucket = "cemp_raw"
}

resource "aws_sqs_queue" "cemp_raw_snowpipe" {
  name                       = "cemp_raw_snowpipe"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600 # 14 days
}

resource "aws_sns_topic" "cemp_raw_snowpipe" {
  name = "cemp_raw_snowpipe"
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
  bucket = "cemp_raw"

  topic {
    topic_arn = aws_sns_topic.cemp_raw_snowpipe.arn
    events    = ["s3:ObjectCreated:*"]

    # Optional: prefix filter for only certain paths
    filter_prefix = "" # leave empty to capture all
    # filter_suffix = ".json" # optional
  }

  depends_on = [aws_sns_topic_subscription.cemp_raw_sns_to_sqs]
}
