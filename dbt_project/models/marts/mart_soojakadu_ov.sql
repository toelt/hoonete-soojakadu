-- mart_soojakadu_ov: Soojakao intensiivsus (kWh/m²/aastas) omavalitsuse kaupa.
-- Allikas: int_soojakadu (päevane soojakadu OV × päev)
-- Mõõdik #1 arhitektuuris: Soojakao intensiivsus
SELECT
    ov_kood,
    ov_nimi,
    MAX(hoonete_arv)                                               AS hoonete_arv,
    MAX(kogupindala_m2)                                            AS kogupindala_m2,
    SUM(soojakadu_kwh_paevas)                                      AS soojakadu_kwh_aastas,
    ROUND(
        SUM(soojakadu_kwh_paevas) / NULLIF(MAX(kogupindala_m2), 0),
        2
    )                                                              AS soojakao_intensiivsus_kwh_m2_aastas,
    COUNT(DISTINCT kuupaev)                                        AS paevade_arv
FROM {{ ref('int_soojakadu') }}
GROUP BY ov_kood, ov_nimi
ORDER BY soojakao_intensiivsus_kwh_m2_aastas DESC
