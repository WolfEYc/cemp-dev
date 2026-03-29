
CREATE OR REPLACE TABLE khols.promoter_score AS
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
FROM khols.raw_events;

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
FROM khols.promoter_score;
