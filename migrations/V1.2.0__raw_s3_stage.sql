CREATE OR REPLACE STAGE raw_stage.s3_stage
  STORAGE_INTEGRATION = cemp_raw_s3_integration
  URL = 's3://cemp-raw/';
