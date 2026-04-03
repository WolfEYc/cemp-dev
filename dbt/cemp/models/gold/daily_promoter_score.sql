
{{ 
    config(
        materialized='incremental',
        unique_key='row_hash',
        cluster_by=['event_date']
    )
}}

select 
    current_timestamp() AS pipeline_event_ts,
    hash(DATE(event_ts), vendor, product_id, country, state, referral_type, referral_id) as row_hash,
    DATE(event_ts) as event_date,
    vendor,
    product_id,
    country,
    state,
    referral_type,
    referral_id,
    (count_if(score >= 9)::float / count(*)) - (count_if(score <= 6)::float / count(*)) as nps,
    count(*) as num_entries
from {{ ref('promoter_score') }}
{% if is_incremental() %}
    where DATE(event_ts) >= DATEADD(DAY, -7, CURRENT_DATE())
{% endif %}
group by DATE(event_ts), vendor, product_id, country, state, referral_type, referral_id