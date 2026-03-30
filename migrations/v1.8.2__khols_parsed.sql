CREATE OR REPLACE VIEW khols.raw_events AS
SELECT *
FROM raw_stage.raw_events
WHERE
    dataset_type = 'nps'
AND vendor = 'khols'
AND dataset_id = 'v1';

ALTER TABLE raw_stage.raw_events SET CHANGE_TRACKING = TRUE;

CREATE OR REPLACE STREAM khols.raw_stream
ON VIEW khols.raw_events
APPEND_ONLY = TRUE;

CREATE OR REPLACE VIEW khols.promoter_score_parsed_stream AS
SELECT
    pipeline_event_id,
    CURRENT_TIMESTAMP() AS pipeline_event_ts,
    ingest_ts,
    payload:country::string AS country,
    payload:state::string AS state,
    payload:event_id::string AS event_id,
    payload:event_timestamp::string AS event_timestamp,
    payload:khols_shopper_id::string AS khols_shopper_id,
    payload:promoter_score::int AS promoter_score,
    payload:referal_store_code::string AS referral_store_code
FROM khols.raw_stream;

CREATE OR REPLACE TABLE khols.promoter_score AS
SELECT * FROM khols.promoter_score_parsed_stream;

CREATE OR REPLACE TASK khols.promoter_score_ingest
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '1 minute'
    WHEN SYSTEM$STREAM_HAS_DATA('khols.raw_stream')
AS
INSERT INTO khols.promoter_score
SELECT * FROM khols.promoter_score_parsed_stream;

ALTER TABLE khols.promoter_score SET CHANGE_TRACKING = TRUE;

CREATE OR REPLACE STREAM khols.promoter_score_stream
ON TABLE khols.promoter_score
APPEND_ONLY = TRUE;

ALTER TABLE bronze.promoter_score ADD COLUMN referral_type STRING;
ALTER TABLE bronze.promoter_score ADD COLUMN referral_id STRING;

CREATE OR REPLACE VIEW khols.promoter_score_bronze AS
SELECT
    pipeline_event_id,
    'khols' AS vendor,
    ingest_ts,
    'khols_C1_card' AS product_id,
    event_id,
    event_timestamp AS event_ts,
    promoter_score AS score,
    country,
    state,
    'in_store' AS referral_type,
    referral_store_code AS referral_id
FROM khols.promoter_score_stream;

CREATE OR REPLACE TASK khols.promoter_score_bronze_fan_in
    WAREHOUSE = COMPUTE_WH
    AFTER khols.promoter_score_ingest
AS
INSERT INTO bronze.promoter_score (
    pipeline_event_id,
    vendor,
    ingest_ts,
    product_id,
    event_id,
    event_ts,
    score,
    country,
    state,
    referral_type,
    referral_id
)
SELECT    
    pipeline_event_id,
    vendor,
    ingest_ts,
    product_id,
    event_id,
    event_ts,
    score,
    country,
    state,
    referral_type,
    referral_id
FROM khols.promoter_score_bronze;
    
