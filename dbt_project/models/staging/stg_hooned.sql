WITH hooned AS (
  SELECT
    ehr_kood,
    esmane_kasutus AS ehitusaasta,
    suletud_netopind,
    ov_nimi,
    REGEXP_REPLACE(energiamargis, ' \(.*\)', '') AS energiamargis
  FROM {{ source('staging', 'ehitisregister_raw') }}
  WHERE esmane_kasutus BETWEEN 1800 AND 2026
    AND suletud_netopind > 0
    AND suletud_netopind < 100000
    AND ov_nimi IS NOT NULL
)
SELECT DISTINCT ON (ehr_kood) *
FROM hooned
ORDER BY ehr_kood
