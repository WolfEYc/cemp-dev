CREATE ICEBERG TABLE cemp_iceberg_db.bronze.promoter_scores (
    vendor STRING,
    event_id STRING,
    product_id STRING,
    score INT,
    event_ts TIMESTAMP,
    ingest_ts TIMESTAMP,
)
CATALOG = 'glue_catalog_int'
EXTERNAL_VOLUME = 'iceberg_ext_vol'
BASE_LOCATION = '/warehouse/cemp_iceberg_db/bronze/promoter_scores/'
;
