
CREATE TABLE ingest_control_plane.pipeline_partitions (
    dataset STRING,
    partition_date DATE,
    s3_path STRING,
    discovered_at TIMESTAMP,
    status STRING,
    processed_at TIMESTAMP
);
