ALTER TABLE raw_stage.raw_events DROP COLUMN s3_file_version;
ALTER TABLE raw_stage.raw_events ADD COLUMN s3_last_modified TIMESTAMP NOT NULL;
