-- stg_elektrihinnad: Nord Pool Eesti börsielektri hinna agregeerimine päeva keskmiseks.
-- Allikas: staging.elektrihinnad_raw (Elering API /nps/price)
-- Tulemus: 1 rida päeva kohta, keskmine hind €/MWh Eesti ajatsoonis.
SELECT
    (timestamp AT TIME ZONE 'Europe/Tallinn')::date AS kuupaev,
    ROUND(AVG(hind), 2)                              AS keskmine_hind_eur_mwh
FROM {{ source('staging', 'elektrihinnad_raw') }}
WHERE hind IS NOT NULL
GROUP BY (timestamp AT TIME ZONE 'Europe/Tallinn')::date
