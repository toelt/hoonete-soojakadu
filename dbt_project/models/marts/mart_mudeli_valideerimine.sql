-- mart_mudeli_valideerimine: Mudeli soojakao võrdlus tegeliku riikliku elektritarbimisega.
-- Arvutab Pearsoni korrelatsiooni mudeli päevase soojakao (kõik OV-d summeeritult)
-- ja Eleringi tegeliku päevase elektritarbimise vahel.
-- Allikad: int_soojakadu (mudel) + stg_tarbimine (tegelik tarbimine MWh).
-- Mõõdik #4 arhitektuuris: Mudeli valideerimine

WITH mudel AS (
    -- Mudeli päevane soojakadu üle kogu Eesti (kWh)
    SELECT
        kuupaev,
        SUM(soojakadu_kwh_paevas) AS mudel_kwh
    FROM {{ ref('int_soojakadu') }}
    GROUP BY kuupaev
),

tegelik AS (
    -- Tegelik riiklik päevane elektritarbimine (kWh)
    SELECT
        kuupaev,
        tarbimine_mwh * 1000 AS tegelik_kwh
    FROM {{ ref('stg_tarbimine') }}
    WHERE tarbimine_mwh IS NOT NULL
),

vordlus AS (
    SELECT
        m.kuupaev,
        m.mudel_kwh,
        t.tegelik_kwh,
        ABS(m.mudel_kwh - t.tegelik_kwh) AS absoluutne_viga_kwh
    FROM mudel m
    INNER JOIN tegelik t ON m.kuupaev = t.kuupaev
),

-- Pearsoni r arvutatakse eraldi, et vältida topeltkutset makrole
korr AS (
    SELECT {{ pearson_r('mudel_kwh', 'tegelik_kwh') }} AS r
    FROM vordlus
),

-- Ülejäänud agregaadid
agg AS (
    SELECT
        COUNT(*)                                   AS paevade_arv,
        ROUND(AVG(mudel_kwh), 0)                   AS keskmine_mudel_kwh_paevas,
        ROUND(AVG(tegelik_kwh), 0)                 AS keskmine_tegelik_kwh_paevas,
        ROUND(AVG(absoluutne_viga_kwh), 0)         AS keskmine_absoluutne_viga_kwh,
        ROUND(
            AVG(absoluutne_viga_kwh)
            / NULLIF(AVG(tegelik_kwh), 0) * 100,
            1
        )                                           AS mape_protsent
    FROM vordlus
)

SELECT
    a.paevade_arv,
    ROUND(k.r::numeric, 4)  AS pearson_r,
    ROUND(POWER(k.r, 2)::numeric, 4) AS r_ruut,
    a.keskmine_mudel_kwh_paevas,
    a.keskmine_tegelik_kwh_paevas,
    a.keskmine_absoluutne_viga_kwh,
    a.mape_protsent
FROM agg a
CROSS JOIN korr k
