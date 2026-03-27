CREATE TABLE bronze.promoter_score (
    pipeline_event_id STRING NOT NULL,
    pipeline_event_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP() NOT NULL,
    vendor STRING NOT NULL,
    ingest_ts TIMESTAMP NOT NULL,
    product_id STRING,
    event_id STRING,
    event_ts TIMESTAMP,
    score INT
)
CLUSTER BY (DATE(ingest_ts), vendor)
