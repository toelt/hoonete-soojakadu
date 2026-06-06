-- Pearsoni r peab matemaatiliselt olema -1 kuni 1 vahel.
-- Kui see tingimus ei kehti, on arvutuses viga.
select ov_kood, ilmastikutundlikkus_r
from {{ ref('mart_ilmastikutundlikkus') }}
where ilmastikutundlikkus_r < -1
   or ilmastikutundlikkus_r > 1
