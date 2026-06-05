-- stg_ilmaandmed: Tunniandmete agregeerimine päeva keskmiseks temperatuuriks.
-- Allikas: staging.ilmaandmed_raw (Open-Meteo archive API)
-- Tulemus: 1 rida iga ilmajaama ja päeva kohta
SELECT
    jaam_kood,
    kuupaev,
    ROUND(AVG(temperatuur), 1) AS keskmine_temp
FROM {{ source('staging', 'ilmaandmed_raw') }}
WHERE temperatuur IS NOT NULL
GROUP BY jaam_kood, kuupaev
