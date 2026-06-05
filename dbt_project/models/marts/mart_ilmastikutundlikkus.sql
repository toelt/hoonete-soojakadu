-- mart_ilmastikutundlikkus: Pearsoni korrelatsioon päeva keskmise temperatuuri
-- ja omavalitsuse päevase soojakao vahel.
-- Kõrgem |r| → tugevam lineaarne seos ilmastiku ja soojakao vahel.
-- Negatiivne r → külmem ilm = suurem soojakadu (oodatav).
-- Allikas: int_soojakadu (sisaldab nüüd keskmine_temp veergu).
-- Mõõdik #2 arhitektuuris: Ilmastikutundlikkuse indeks
SELECT
    ov_kood,
    ov_nimi,
    ROUND({{ pearson_r('keskmine_temp', 'soojakadu_kwh_paevas') }}::numeric, 4) AS ilmastikutundlikkus_r,
    COUNT(*)                                                                     AS paevade_arv
FROM {{ ref('int_soojakadu') }}
WHERE keskmine_temp IS NOT NULL
GROUP BY ov_kood, ov_nimi
HAVING COUNT(*) >= 30  -- miinimum 30 päeva usaldusväärse korrelatsiooni jaoks
ORDER BY ilmastikutundlikkus_r ASC
