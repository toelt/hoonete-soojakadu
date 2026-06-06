-- mart_soojakadu_ov: Soojakao intensiivsus (kWh/m²/aastas) omavalitsuse kaupa.
-- Allikas: int_soojakadu (päevane soojakadu OV × päev)
-- Mõõdik #1 arhitektuuris: Soojakao intensiivsus
--
-- Annualiseerimine: SUM(päevas) / päevade_arv * 365 → aastane ekvivalent
SELECT
    ov_kood,
    ov_nimi,
    MAX(hoonete_arv)                                               AS hoonete_arv,
    MAX(kogupindala_m2)                                            AS kogupindala_m2,
    COUNT(DISTINCT kuupaev)                                        AS paevade_arv,
    ROUND(
        SUM(soojakadu_kwh_paevas) / NULLIF(COUNT(DISTINCT kuupaev), 0) * 365,
        0
    )                                                              AS soojakadu_kwh_aastas,
    ROUND(
        SUM(soojakadu_kwh_paevas)
        / NULLIF(COUNT(DISTINCT kuupaev), 0)
        * 365
        / NULLIF(MAX(kogupindala_m2), 0),
        2
    )                                                              AS soojakao_intensiivsus_kwh_m2_aastas
FROM {{ ref('int_soojakadu') }}
GROUP BY ov_kood, ov_nimi
ORDER BY soojakao_intensiivsus_kwh_m2_aastas DESC
