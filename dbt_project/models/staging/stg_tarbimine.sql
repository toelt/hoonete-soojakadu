-- stg_tarbimine: Riikliku tunnitarbimise agregeerimine päeva summeks.
-- Allikas: staging.tarbimine_raw (Elering API /system/with-plan)
-- Tulemus: 1 rida päeva kohta, tarbimine MWh-des Eesti ajatsoonis.
SELECT
    (timestamp AT TIME ZONE 'Europe/Tallinn')::date AS kuupaev,
    SUM(tarbimine)                                   AS tarbimine_mwh
FROM {{ source('staging', 'tarbimine_raw') }}
WHERE tarbimine IS NOT NULL
GROUP BY (timestamp AT TIME ZONE 'Europe/Tallinn')::date
