-- R² peab olema 0 kuni 1 vahel (r² = r * r, alati mittenegatiivne).
select r_ruut
from {{ ref('mart_mudeli_valideerimine') }}
where r_ruut < 0
   or r_ruut > 1
