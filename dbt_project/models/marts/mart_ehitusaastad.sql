-- Ehitusaastate jaotus kümnendite kaupa.
SELECT
  FLOOR(ehitusaasta / 10) * 10 AS aastakymme,
  COUNT(*)                      AS hoonete_arv,
  SUM(suletud_netopind)         AS kogupindala_m2
FROM {{ ref('stg_hooned') }}
WHERE ehitusaasta BETWEEN 1800 AND 2026
GROUP BY aastakymme
ORDER BY aastakymme
