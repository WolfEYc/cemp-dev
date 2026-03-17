
resource "aws_s3_bucket" "cemp_raw" {
  bucket = "cemp_raw"
}

resource "aws_s3_bucket" "cemp_temp" {
  bucket = "cemp_bronze"
}

resource "aws_s3_bucket" "cemp_bronze" {
  bucket = "cemp_bronze"
}

resource "aws_glue_job" "cemp_etl" {
  name     = "cemp_etl"
  role_arn = aws_iam_role.glue_job_role.arn

  command {
    script_location = "s3://cemp_scripts/glue/main.py"
    python_version  = "3"
  }

  glue_version = "4.0"

  worker_type       = "G.1X"
  number_of_workers = 5

  default_arguments = {
    "--job-language" = "python"
    "--TempDir"      = "s3://cemp_temp/"
  }

  timeout = 60
}
