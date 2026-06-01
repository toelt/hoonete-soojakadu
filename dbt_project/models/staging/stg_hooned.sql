WITH hooned AS (
  SELECT
    ehr_kood,
    esmane_kasutus AS ehitusaasta,
    suletud_netopind,
    TRIM(ov_nimi) AS ov_nimi,
    REGEXP_REPLACE(energiamargis, ' \(.*\)', '') AS energiamargis
  FROM {{ source('staging', 'ehitisregister_raw') }}
  WHERE esmane_kasutus BETWEEN 1800 AND 2026
    AND suletud_netopind > 0
    AND suletud_netopind < 100000
    AND ov_nimi IS NOT NULL
),

dedup AS (
  SELECT DISTINCT ON (ehr_kood) *
  FROM hooned
  ORDER BY ehr_kood, suletud_netopind DESC NULLS LAST
),

normaliseeritud AS (
  SELECT
    d.*,
    COALESCE(m.uus_nimi, d.ov_nimi) AS ov_nimi_norm
  FROM dedup d
  LEFT JOIN {{ ref('omavalitsus_mapping') }} m ON d.ov_nimi = m.vana_nimi
)

SELECT
  n.ehr_kood,
  n.ehitusaasta,
  n.suletud_netopind,
  n.ov_nimi_norm AS ov_nimi,
  n.energiamargis,
  COALESCE(o.ov_kood, '0000') AS ov_kood
FROM normaliseeritud n
LEFT JOIN {{ ref('omavalitsused') }} o ON n.ov_nimi_norm = o.ov_nimi
