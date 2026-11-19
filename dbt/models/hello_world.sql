-- Smallest possible model: Athena runs a CTAS, writes Parquet to S3
-- and registers the table in the Glue Data Catalog.
select
    'hello world'                       as greeting,
    'dbt on Athena via ECS Fargate'     as source,
    cast(current_timestamp as timestamp) as created_at
