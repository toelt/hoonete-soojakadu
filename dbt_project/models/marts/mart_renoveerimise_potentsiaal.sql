-- mart_renoveerimise_potentsiaal: Hinnanguline renoveerimise säästupotentsiaal (€).
-- Arvutab iga omavalitsuse aastase soojakao rahalise kulu ja säästupotentsiaali,
-- kui soojakao intensiivsus viia sihttasemeni 50 kWh/m²/aastas.
-- Allikad: int_soojakadu (soojakadu) + stg_elektrihinnad (keskmine börsihind).
-- Mõõdik #3 arhitektuuris: Renoveerimise potentsiaal

WITH aastane AS (
    SELECT
        ov_kood,
        ov_nimi,
        MAX(hoonete_arv)    AS hoonete_arv,
        MAX(kogupindala_m2) AS kogupindala_m2,
        SUM(soojakadu_kwh_paevas) AS soojakadu_kwh_aastas
    FROM {{ ref('int_soojakadu') }}
    GROUP BY ov_kood, ov_nimi
),

hind AS (
    -- Elering API andmete põhjal keskmine börsielektri hind (€/MWh)
    SELECT AVG(keskmine_hind_eur_mwh) AS keskmine_hind_eur_mwh
    FROM {{ ref('stg_elektrihinnad') }}
    WHERE keskmine_hind_eur_mwh IS NOT NULL
),

-- Sihttase: 50 kWh/m²/aastas (vastab ligikaudu U ≈ 0.5 W/m²K Eesti kliimas).
-- Kui OV intensiivsus on alla sihttaseme, säästupotentsiaal on 0.
potentsiaal AS (
    SELECT
        a.ov_kood,
        a.ov_nimi,
        a.hoonete_arv,
        a.kogupindala_m2,
        a.soojakadu_kwh_aastas,
        ROUND(a.soojakadu_kwh_aastas / NULLIF(a.kogupindala_m2, 0), 2) AS intensiivsus_kwh_m2_aastas,
        ROUND(a.soojakadu_kwh_aastas * h.keskmine_hind_eur_mwh / 1000, 0) AS aastane_soojakulu_eur,
        ROUND(
            GREATEST(
                a.soojakadu_kwh_aastas / NULLIF(a.kogupindala_m2, 0) - 50,
                0
            ) * a.kogupindala_m2 * h.keskmine_hind_eur_mwh / 1000,
            0
        ) AS renoveerimise_saast_eur_aastas,
        ROUND(h.keskmine_hind_eur_mwh, 2) AS keskmine_hind_eur_mwh
    FROM aastane a
    CROSS JOIN hind h
)

SELECT *
FROM potentsiaal
ORDER BY renoveerimise_saast_eur_aastas DESC
