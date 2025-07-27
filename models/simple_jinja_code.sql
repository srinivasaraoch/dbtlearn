{# This jinja code generates SELECT statements to print numbers from 0 to 9 #}
{% set max_number = 10 %}
{% for i in range(max_number) %}
 SELECT {{ i }}  AS NUMBER
 {% if not loop.last  %}
    UNION 
 {% endif %}
{% endfor %} 