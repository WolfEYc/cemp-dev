CREATE PIPE khols.raw_promoter_score
    AUTO_INGEST = TRUE
AS
COPY INTO raw_stage.raw_events (dataset_type, vendor, dataset_id, s3_key, s3_last_modified, payload)
FROM (
    SELECT
        'nps',
        'khols',
        'v1',
        METADATA$FILENAME,
        METADATA$FILE_LAST_MODIFIED,
        $1
    FROM @raw_stage.s3_stage/vendor=khols/dataset=nps/
)
FILE_FORMAT = (FORMAT_NAME = ndjson)
;
