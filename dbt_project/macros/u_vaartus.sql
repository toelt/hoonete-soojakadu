{% macro u_vaartus(ehitusaasta_col) %}
  -- Tagastab ligikaudse piirde keskmise U-väärtuse (W/m²K) ehitusaasta järgi.
  -- Allikas: u_vaartused seed — lihtsustatud standardtabel.
  -- Väärtused on hinnangulised; suhteline pingerida kehtib ka ligikaudsete väärtustega.
  CASE
    WHEN {{ ehitusaasta_col }} BETWEEN 1800 AND 1919 THEN 1.8
    WHEN {{ ehitusaasta_col }} BETWEEN 1920 AND 1940 THEN 1.7
    WHEN {{ ehitusaasta_col }} BETWEEN 1941 AND 1960 THEN 1.6
    WHEN {{ ehitusaasta_col }} BETWEEN 1961 AND 1970 THEN 1.4
    WHEN {{ ehitusaasta_col }} BETWEEN 1971 AND 1980 THEN 1.2
    WHEN {{ ehitusaasta_col }} BETWEEN 1981 AND 1990 THEN 1.0
    WHEN {{ ehitusaasta_col }} BETWEEN 1991 AND 2000 THEN 0.8
    WHEN {{ ehitusaasta_col }} BETWEEN 2001 AND 2005 THEN 0.6
    WHEN {{ ehitusaasta_col }} BETWEEN 2006 AND 2010 THEN 0.5
    WHEN {{ ehitusaasta_col }} BETWEEN 2011 AND 2015 THEN 0.4
    WHEN {{ ehitusaasta_col }} BETWEEN 2016 AND 2020 THEN 0.3
    WHEN {{ ehitusaasta_col }} >= 2021                     THEN 0.25
  END
{% endmacro %}
