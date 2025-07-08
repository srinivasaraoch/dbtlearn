{{
    config(
        materialized='table',
        transient = false
    )
}}


select current_database() db,current_schema() sch,current_warehouse() wh ,current_user() username