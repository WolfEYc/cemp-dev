# Glue Arch

## Control Plane Layer
### Storage
- RDS
- cemp.control_plane.raw_file_log (bucket, key, version_id, event_ts, status, worker_id)

## Raw Layer
### Storage
- S3
- flat structure so vendor can be brainless
- partition by vendor -> dataset s3://cemp-raw/vendor=khols/dataset=nps/
- vendor would get IAM access to dump into here

### Compute
- vendor would write batches into here in some file format
- Send lambda call to update raw_file_log with INSERTED

## Bronze 
### Storage
- Iceberg (S3)
- cemp_iceberg_db.bronze.promoter_scores
- partition by ingest_date
- in rows + parsed + relationalized / flattened + extracted + normalized
- likely 0 filtering
- dupes are totally allowed (and expected) here
- vendor agnostic
- table schema example: (vendor, product_id, event_id, score, event_ts, ingest_ts)

### Compute
- Glue Spark job
- Airflow orchestrated
- Append only, dedup later, storage is cheap, compute isn't. df.writeTo("glue.cemp.bronze.nps").append()

## Silver
### Storage
- Iceberg (S3)
- glue.cemp.silver.nps
- partition by event_date
- vendor agnostic

### Compute
- Glue spark job
- airflow orchestrated
- Grab distinct event_date's of records with ingest_date within provided time window
- Or accept manually provided event_date range
- overwrite affected partitions, faster then row level merge at this scale. df.writeTo("glue.cemp.silver.nps").overwritePartitions()

## DAG steps
### main Dag
1. get files that are INSERTED or FAILED within ingest time window (pending it only failed <X times)
2. invoke per dataset DAG (passing group of files)

### per dataset DAG
3. insert PROCESSING for these files
4. invoke bronze spark job per dataset, passing in the files in that dataset 
5. insert PROCESSED on success for dataset files, FAILED otherwise

### main DAG
6. invoke silver spark job for this ingest time window

