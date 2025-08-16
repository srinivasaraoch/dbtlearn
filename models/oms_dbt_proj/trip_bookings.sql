{{ config(materialized='table') }}

select * from {{ source('training', 'trip_bookings') }}
