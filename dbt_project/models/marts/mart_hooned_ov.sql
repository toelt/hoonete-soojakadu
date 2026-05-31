-- Hoonete statistika omavalitsuse kaupa.
SELECT
  ov_kood,
  ov_nimi,
  COUNT(*)                        AS hoonete_arv,
  SUM(suletud_netopind)           AS kogupindala_m2,
  ROUND(AVG(suletud_netopind))    AS keskmine_pindala_m2,
  ROUND(AVG(ehitusaasta))         AS keskmine_ehitusaasta,
  COUNT(*) FILTER (WHERE ehitusaasta < 1960) AS vanu_hooneid,
  COUNT(*) FILTER (WHERE energiamargis IS NOT NULL AND energiamargis != '') AS margisega_hooneid
FROM {{ ref('stg_hooned') }}
GROUP BY ov_kood, ov_nimi
ORDER BY hoonete_arv DESC
