-- mart_soojakadu_ov: Soojakao intensiivsus omavalitsuse kaupa, päevase detailsusega.
-- Superset saab ise agregeerida nädala/kuu/aasta kaupa ja seada kuupäeva filtri.
-- Mõõdik #1 arhitektuuris: Soojakao intensiivsus
SELECT
    ov_kood,
    ov_nimi,
    kuupaev,
    hoonete_arv,
    kogupindala_m2,
    keskmine_temp,
    soojakadu_kwh_paevas,
    ROUND(
        soojakadu_kwh_paevas / NULLIF(kogupindala_m2, 0),
        3
    ) AS soojakao_intensiivsus_kwh_m2_paevas
FROM {{ ref('int_soojakadu') }}
