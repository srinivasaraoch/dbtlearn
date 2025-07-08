
 {% macro cleaning (source_name, table_name) %}
    {%- if source_name and table_name -%}
    {%- set relation = source(source_name, table_name) -%}
    {%- else -%}
    {%- set relation = ref(table_name) -%}
    {%- endif -%}
    {%- set columns = adapter.get_columns_in_relation(relation) -%}
	
    select 
        {% for col in columns -%}
            {{ col.column }} as {{ col.column }}_orig,
            case when lower(trim({{col.column}})) in ( '', ' ','[]','null') then null
            else  {{col.column}}
            end as {{ col.column }}
            {%- if not loop.last -%}, {%- endif %}
        {% endfor %}
    from {{ relation }}
{% endmacro %}

{% macro number(columns) %}
    {% set columns = columns.split(",") %}
    {% for col in columns -%}
        {{ col.strip() }}_orig as {{ col.strip() }}_orig,
        try_to_number(
            replace(replace(
                    case 
                        when {{ col.strip() }} like all('(%','%)') 
                        then '-' || replace(replace({{ col.strip() }}, '('), ')') 
                        else {{ col.strip() }}
                    end, 
                '$'), ',')) as {{ col.strip() }} 
        {%- if not loop.last -%},{%- endif %}
    {% endfor %}
{% endmacro %}

{% macro decimal(columns, precision=20, scale=4) %}
    {% set columns = columns.split(",") %}
    {% for col in columns -%}
        {{ col.strip() }}_orig as {{ col.strip() }}_orig,
        try_to_decimal(
            replace(
                replace(
                    case 
                        when {{ col.strip() }} like all('(%','%)') 
                        then '-' || replace(replace({{ col.strip() }}, '('), ')') 
                        else {{ col.strip() }}
                    end, 
                '$'), ','), precision, scale) as {{ col.strip() }}
        {%- if not loop.last -%},{%- endif %}
    {% endfor %}
{% endmacro %}

{% macro timestamp_utc(columns, format=None, timezone=None) %}
    {# Split the columns string into a list and strip whitespace #}
    {% set columns = columns.split(",") %}
    {% for col in columns -%}
        {% if format is none %}
            {# Handle cases where no format is provided #}
            {% if timezone is not none %}
                convert_timezone({{ timezone }}, 'UTC', TRY_TO_TIMESTAMP_NTZ({{ col.strip() }}::varchar)) as {{ col.strip() }}
            {% else %}
                TRY_TO_TIMESTAMP_NTZ({{ col.strip() }}::varchar) as {{ col.strip() }}
            {% endif %}
        {% else %}
            {% if timezone is not none %}
                convert_timezone({{ timezone }}, 'UTC', try_to_{{ format }}({{ col.strip() }}::varchar)) as {{ col.strip() }}
            {% else %}
                try_to_{{ format }}({{ col.strip() }}::varchar) as {{ col.strip() }}
            {% endif %}
        {% endif %}
        {%- if not loop.last -%},{%- endif %}
    {% endfor %}
{% endmacro %}

{% macro date(columns, format=None) %}
    {% set columns = columns.split(",") %}
    {% for col in columns -%}
        {% set column_name = col.strip() %}
        try_to_timestamp({{ column_name }}::varchar 
            {%- if format is not none -%}, '{{ format }}'{%- endif -%}) as {{ column_name }}
        {%- if not loop.last -%},{%- endif %}
    {% endfor %}
{% endmacro %}

{% macro varchar(columns, target_type='varchar') %}
    {%- set columns = columns.split(",") %}
    {%- for col in columns %}
        try_cast(trim({{ col.strip() }}) as {{ target_type }}) as {{ col.strip() }}
        {%- if not loop.last -%}, {%- endif %}
    {%- endfor %}
{% endmacro %}

{% macro geography(longitude=None, latitude=None, geography_value=None) %}
    {%- if geography_value is not none -%}
        {{ geography_value.strip() }}_orig,
        try_to_geography({{ geography_value.strip() }}) as {{ geography_value.strip() }}
    {%- else -%}
        {% if longitude and latitude %}
            {{ latitude.strip() }}_orig, {{ longitude.strip() }}_orig,
            try_to_geography(concat('POINT(', {{ longitude.strip() }}, ' ', {{ latitude.strip() }}, ')')) as geography_point
        {% else %}
            null as geography_value_missing
        {% endif %}
    {%- endif -%}
{% endmacro %}

                                                                                                                                   
--("column1:tag1,column2:tag2,column3:tag3",'tag_name') always use tag from [address,email,personal,phone]
{% macro masking(columns_with_tags,tag_name) %} 
    {% set columns_with_tags = columns_with_tags.split(",") %}
    {% set masked_tag = tag_name %}
    
    alter table {{ this }} modify
    {%- for column_with_tag in columns_with_tags -%}
        {% set parts = column_with_tag.split(":") %}
        {% set col = parts[0].strip() %}
        {% set tag = parts[1].strip() %}
        column {{ col }} set tag {{ database }}.{{ schema }}.{{masked_tag}}='{{ tag }}'
        {%- if not loop.last -%},{%- endif %}
    {%- endfor -%}
{% endmacro %}

{% macro surrogate_key(columns,key_name) %}
{% set columns_list = columns.split(",") %}
{%- set trimmed_columns = [] -%}
    
    {%- for col in columns_list -%}
        {%- set trimmed_col = col.strip() -%}
        {%- do trimmed_columns.append( trimmed_col) -%}
    {%- endfor -%}
    {{ dbt_utils.generate_surrogate_key(trimmed_columns) }} as {{key_name}}
   
{% endmacro %}

{% macro surrogate_key_with_all_col(source_name, table_name, key_name, exclude_columns="") %}
    {%- set relation = source(source_name, table_name) -%}
    {%- set columns = adapter.get_columns_in_relation(relation) -%}
    {%- set excluded = exclude_columns.split(",") | map(attribute='strip') | list -%}
    {%- set trimmed_columns = [] -%}
    
    {%- for col in columns -%}
        {%- if col.column not in excluded -%}
            {%- do trimmed_columns.append(col.column) -%}
        {%- endif -%}
    {%- endfor -%}
    
    {{ dbt_utils.generate_surrogate_key(trimmed_columns) }} as {{key_name}}
{% endmacro %}

{% macro recency(source_name, table_name, date_column, recency_in_days) %}
    {%- if recency_in_days >= 0 %}
        with max_date as 
        (
            select '{{table_name}}' as name, max({{ date_column }})::date as max_date 
            from {{ source(source_name, table_name) }} 
        )
        select * 
        from max_date 
        where max_date < current_date - ({{ recency_in_days }})
    {%- else -%} 
        select 'recency_leads_future_date' from dual 
    {%- endif %}
{% endmacro %}

{% macro pick_records_by_order(unique_key_combn,order_column,order_type)   %}
   qualify row_number() over (partition by {{unique_key_combn}} order by {{order_column}} {{order_type}} )=1
{% endmacro %}

{% macro timestamp_tz(columns, format=None, suffix="_localtimestamp") %}
    {% if columns is string %}
        {% set columns = columns.split(",") %}
    {% endif %}
    {% for col in columns %}
        try_to_timestamp_tz(
            ({{ col.strip() }}::varchar)
            {%- if format -%}, '{{ format }}' {%- endif -%}
        ) as {{ col.strip() }}{{ suffix }}
        {%- if not loop.last -%}, {%- endif -%}
    {% endfor %}
{% endmacro %}

{% macro time(columns, format=None, suffix="_time") %}
    {% if columns is string %}
        {% set columns = columns.split(",") %}
    {% endif %}
    {% for col in columns %}
        try_to_time(
            ({{ col.strip() }}::varchar)
            {%- if format -%}, '{{ format }}' {%- endif -%}
        ) as {{ col.strip() }}{{ suffix }}
        {%- if not loop.last -%}, {%- endif -%}
    {% endfor %}
{% endmacro %}

--The epoch_to_timestamp_utc macro is a useful tool for converting epoch values into TIMESTAMP data
{% macro epoch_to_timestamp_utc(columns, suffix="_ts", divide_by=None) %}
    {% set columns = columns.split(",") %}
    {% for col in columns %}
        {{ col.strip() }} as {{ col.strip() }}_orig,
        try_to_timestamp(
            (
                {%- if divide_by -%}
                    {{ col.strip() }}::numeric / {{ divide_by }}
                {%- else -%}
                    {{ col.strip() }}::varchar
                {%- endif -%}
            )
        ) as {{ col.strip() }}{{ suffix }}
        {%- if not loop.last -%},{%- endif %}
    {% endfor %}
{% endmacro %}

{% macro get_column_list_orig_named_columns(table_name) %}
    {%- set relation = ref(table_name) -%}
    {%- set columns = adapter.get_columns_in_relation(relation) -%}
    
    {%- set orig_columns = [] -%}
    {%- for col in columns -%}
        {%- if col.column.endswith('_ORIG') -%}
            {%- do orig_columns.append(col.column) -%}
        {%- endif -%}
    {%- endfor -%}

    {{ return(orig_columns | join(',')) }}
{% endmacro %}


{% macro snowflake_create_external_table(source_node) %}

    {%- set columns = source_node.columns.values() -%}
    {%- set external = source_node.external -%}
    {%- set partitions = external.partitions -%}
    {%- set name = source_node.name -%}

    {%- set is_csv = dbt_external_tables.is_csv(external.file_format) -%}

    {# https://docs.snowflake.net/manuals/sql-reference/sql/create-external-table.html #}
    {# This assumes you have already created an external stage #}
    create or replace external table
 {{source(source_node.source_name, source_node.name)}}
    {%- if columns or partitions -%}
    (
        {%- if partitions -%}{%- for partition in partitions %}
            {{partition.name}} {{partition.data_type}} as {{partition.expression}}{{- ',' if not loop.last or columns|length > 0 -}}
        {%- endfor -%}{%- endif -%}
        {%- for column in columns %}
            {%- set column_quoted = adapter.quote(column.name) if column.quote else column.name %}
            {%- set col_expression -%}
                {%- set col_id = 'value:c' ~ loop.index if is_csv else 'value:' ~ column_quoted -%}
                (case when is_null_value({{col_id}}) or lower({{col_id}}) = 'null' then null else {{col_id}} end)
            {%- endset %}
            {{column_quoted}} {{column.data_type}} as ({{col_expression}}::{{column.data_type}})
            {{- ',' if not loop.last -}}
        {% endfor %}
    )
    {%- endif -%}
    {% if partitions %} partition by (
{{partitions|map(attribute='name')|join(', ')}}) {% endif %}
    {%- if external.condition -%}
      {%- set run_query_asof -%}
      select {{external.condition}} 
      {%- if external.table_name %}
        from {{ ref(external.table_name) }}
      {%- endif -%}
      {%- if external.filter %}
        where {{external.filter}}
      {%- endif -%}
      ;
      {%- endset -%}
      {%- set results = run_query(run_query_asof) -%}
      {%- if execute -%}
                {# Return the first column #}
      {%- set results_list = results.columns[0].values() -%}
      {%- else -%}
      {%- set results_list = [] -%}
      {%- endif %}
      location = {{external.location}}{{ results_list[0] }}  {# stage #}
    {%- else %}
      location = {{external.location}}  {# stage #}
    {%- endif %}
    {% if external.auto_refresh in (true, false) -%}
      auto_refresh = {{external.auto_refresh}}
    {%- endif %}
    {% if external.pattern -%} pattern = '{{external.pattern}}' {%- endif %}
    {% if external.integration -%} integration = '{{external.integration}}' {%- endif %}
    file_format = {{external.file_format}}
    {% if external.table_format -%} table_format = '{{external.table_format}}' {%- endif %}
{% endmacro %}

{% macro clone_schema(src_db,src_schema,tgt_db,tgt_schema) %}
{% set layer_name, tgt_env_name = tgt_db.split('_') %}
{% set layer_name, src_env_name = src_db.split('_') %}
{% if tgt_env_name.lower() !=src_env_name.lower() %}
    {% if tgt_env_name.lower() != 'prod' and src_env_name.lower()!='dev' %}
{% set sql %}
    create or replace schema {{tgt_db}}.{{tgt_schema}} clone {{src_db}}.{{src_schema}};
{% endset %}
{% do run_query(sql) %}
    {% else %}
    {{ exceptions.raise_compiler_error("Lower environment data can't be clone to higher environment") }}
    {% endif %}
{% else %}
{{ exceptions.raise_compiler_error("same database can't clone") }}
{% endif %}
{% do log("Schema cloned successfully", info=True) %}
{% endmacro %}

{% macro mark_deleted_flag(tgt_key_column_id, src_key_column_id,updated_date,source_table_name) %}
update {{ this }} set is_deleted='Y',{{updated_date}}=sysdate() where {{tgt_key_column_id}} in (
select {{tgt_key_column_id}} from {{ this }}
minus
select {{src_key_column_id}} from {{ database }}.{{ schema }}.{{source_table_name}})
and is_deleted='N'
{% endmacro %}

{% macro ops_sp_execution(stat) %}
    {% if target.name == 'prod' %}
        {% set results = run_query("SELECT distinct trim(spname) as spname ,
        active_flag  
        FROM  transform_prod.prs_dataops.ops_sp_list
         where active_flag='Y' 
           and run_stat = '" ~ stat ~ "' ") %}

        {% set sp_list = [] %}

        {% for sp_name in results.rows %}
            {% set sp_list = sp_list.append(sp_name[0]) %}
        {% endfor %}

        {% for sp_l in sp_list %}
            {% do run_query("CALL " ~ sp_l ~ "();") %}
        {% endfor %}
    
    {% else %}
        {% do run_query("SELECT * FROM DUAL;") %}
    {% endif %}
{% endmacro %}

{% macro remove_dup_artifacts_tables() %}
{%- set artifacts_schema -%}
 {{ var('artifacts_schema') }}
{%- endset -%}
{% set sql %}
    create or replace table {{ target.database }}.{{ artifacts_schema }}.models as 
    select * from {{ target.database }}.{{ artifacts_schema }}.models qualify case when lag(checksum) over (partition by NAME order by RUN_STARTED_AT asc)=checksum then 1 else 0 end =0;
    create or replace table {{ target.database }}.{{ artifacts_schema }}.seeds as 
    select * from {{ target.database }}.{{ artifacts_schema }}.seeds qualify case when lag(checksum) over (partition by NAME order by RUN_STARTED_AT asc)=checksum then 1 else 0 end =0;
    create or replace table {{ target.database }}.{{ artifacts_schema }}.snapshots as 
    select * from {{ target.database }}.{{ artifacts_schema }}.snapshots qualify case when lag(checksum) over (partition by NAME order by RUN_STARTED_AT asc)=checksum then 1 else 0 end =0;
    create or replace table {{ target.database }}.{{ artifacts_schema }}.sources as 
    select * from {{ target.database }}.{{ artifacts_schema }}.sources qualify row_number() over (partition by NAME order by RUN_STARTED_AT asc)=1;
    create or replace table {{ target.database }}.{{ artifacts_schema }}.tests as 
    select * exclude (checksum) from (select *,ALL_RESULTS:checksum.checksum::varchar as checksum from {{ target.database }}.{{ artifacts_schema }}.tests) qualify case when lag(checksum) over (partition by NAME order by RUN_STARTED_AT asc)=checksum then 1 else 0 end =0;
{% endset %}
{% do run_query(sql) %}
{% endmacro %}

