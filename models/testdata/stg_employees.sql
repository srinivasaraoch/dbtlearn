{{ config(materialized='table') }}

select
    value:c1::varchar    as emp_id,
    value:c2::varchar    as first_name,
    value:c3::varchar    as last_name,
    value:c4::varchar    as department,
    value:c5::varchar    as salary,
    value:c6::date       as join_date,
    value:c7::varchar    as email,
    filename,
    asof_date
from {{ source('exttbl', 'employees_ext') }}