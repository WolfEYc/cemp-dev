CREATE TABLE raw_stage.raw_events (
    pipeline_event_id VARCHAR(36) DEFAULT UUID_STRING() NOT NULL, 
    pipeline_event_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP() NOT NULL,
    ingest_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP() NOT NULL,
    dataset_type STRING NOT NULL,
    vendor STRING NOT NULL,
    dataset_id STRING NOT NULL,
    s3_key STRING NOT NULL,
    s3_file_version STRING NOT NULL,
    payload VARIANT
)
CLUSTER BY (dataset_type, vendor, dataset_id, TO_DATE(ingest_ts));
