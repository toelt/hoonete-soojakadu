{% macro pearson_r(x, y) %}
  -- Pearsoni korrelatsioonikordaja r:
  --   r = (n·Σxy − Σx·Σy) / √( (n·Σx² − (Σx)²) · (n·Σy² − (Σy)²) )
  --
  -- Kasutamine:
  --   SELECT ov_kood, pearson_r('keskmine_temp', 'soojakadu_kwh_paevas') AS r
  --   FROM int_soojakadu GROUP BY ov_kood
  --
  -- Tulemus NULL, kui dispersioon mõlemas muutujas on null (kõik väärtused samad)
  -- või kui andmeid on vähem kui 2 rida.
  (
    (COUNT(*) * SUM({{ x }} * {{ y }}) - SUM({{ x }}) * SUM({{ y }}))
    / NULLIF(
        SQRT(NULLIF(COUNT(*) * SUM({{ x }} * {{ x }}) - SUM({{ x }}) * SUM({{ x }}), 0))
        * SQRT(NULLIF(COUNT(*) * SUM({{ y }} * {{ y }}) - SUM({{ y }}) * SUM({{ y }}), 0)),
        0
      )
  )
{% endmacro %}
