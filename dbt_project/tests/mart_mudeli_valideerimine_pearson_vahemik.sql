-- Pearsoni r peab olema -1 kuni 1 vahel.
select pearson_r
from {{ ref('mart_mudeli_valideerimine') }}
where pearson_r < -1
   or pearson_r > 1
