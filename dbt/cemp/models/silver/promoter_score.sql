

{{ 
    config(
        materialized='incremental',
        unique_key='event_id',
        cluster_by=['DATE(event_ts)', 'vendor']
    )
}}

select 
    pipeline_event_id,
    current_timestamp() AS pipeline_event_ts,
    vendor,
    ingest_ts,
    product_id,
    event_id,
    event_ts,
    score
from bronze.promoter_score
where 
    event_id is not null
and event_ts is not null
and score is not null
{% if is_incremental() %}
    and ingest_ts >= (select max(ingest_ts) from {{ this }})
{% endif %}
qualify row_number() over (partition by event_id order by event_ts desc, ingest_ts desc) = 1

