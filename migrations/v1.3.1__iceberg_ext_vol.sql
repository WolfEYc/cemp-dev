CREATE OR REPLACE EXTERNAL VOLUME iceberg_ext_vol
  STORAGE_LOCATIONS = (
    (
      NAME = 's3_loc'
      STORAGE_PROVIDER = 'S3'
      STORAGE_BASE_URL = 's3://cemp-iceberg-db/'
      STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::739605955065:role/snowflake-storage-role'
    )
  );
