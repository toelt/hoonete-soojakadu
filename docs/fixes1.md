# Parandused — koodibaasi ülevaatus (2026-06-06)

---

## 1. `int_soojakadu.sql` — eemaldatud mittevajalik `::integer` cast (rida 156)

**Fail**: `dbt_project/models/intermediate/int_soojakadu.sql`

**Enne**:
```sql
JOIN ov_jaam oj ON h.ov_kood = oj.ov_kood::integer
```

**Pärast**:
```sql
JOIN ov_jaam oj ON h.ov_kood = oj.ov_kood
```

**Miks**: `stg_hooned.ov_kood` on TEXT (`COALESCE(o.ov_kood, '0000')`) ja `ov_jaam` CTE väärtused on samuti TEXT (`('0130', 'TLN')`). `::integer` cast oli mittevajalik — DuckDB tegi implitsiitse teisenduse (`'0130' → 130`), kuid standard-PostgreSQL-is tekitaks see type mismatch vea. Lisaks on see eksitav lugejale, kes eeldab, et tüübid erinevad.

**Mõju**: JOIN töötab nüüd otsese TEXT=TEXT võrdlusena — korrektsem, portatiivsem.

---

## 2. `mart_mudeli_valideerimine.sql` — `pearson_r` topeltkutse eemaldatud + struktuuriparandus

**Fail**: `dbt_project/models/marts/mart_mudeli_valideerimine.sql`

**Enne**:
```sql
SELECT
    COUNT(*) AS paevade_arv,
    ROUND({{ pearson_r('mudel_kwh', 'tegelik_kwh') }}::numeric, 4) AS pearson_r,
    ROUND(
        POWER({{ pearson_r('mudel_kwh', 'tegelik_kwh') }}, 2)::numeric, 4
    ) AS r_ruut,
    ...
FROM vordlus
```

**Pärast**:
```sql
-- Pearsoni r arvutatakse eraldi CTE-s, et vältida topeltkutset makrole
korr AS (
    SELECT {{ pearson_r('mudel_kwh', 'tegelik_kwh') }} AS r FROM vordlus
),
agg AS (
    SELECT COUNT(*) AS paevade_arv, ... FROM vordlus
)
SELECT
    a.paevade_arv,
    ROUND(k.r::numeric, 4) AS pearson_r,
    ROUND(POWER(k.r, 2)::numeric, 4) AS r_ruut,   -- viitab k.r, mitte uus kutse
    ...
FROM agg a CROSS JOIN korr k
```

**Miks**: Algses koodis kutsuti `pearson_r` makrot **kaks korda** samade andmete peal — iga kutse jooksutas eraldi `COUNT`, `SUM`, `SQRT` agregaadid. Pealegi pole SQL-is võimalik sama `SELECT` sees aliast (`pearson_r`) teises avaldises (`POWER(pearson_r, 2)`) viidata.

Lahendus: `pearson_r` arvutatakse üks kord eraldi `korr` CTE-s. `agg` CTE arvutab ülejäänud agregaadid. Lõpp-SELECT ühendab mõlemad `CROSS JOIN`-iga (mõlemad CTE-d tagastavad ainult 1 rea).

**Mõju**: Üks `pearson_r` kutse kahe asemel, ja korrektne SQL (ei viita sama SELECT-i aliasele).

---

## 3. `pearson_r.sql` — `{% raw %}...{% endraw %}` artefakt eemaldatud (rida 6)

**Fail**: `dbt_project/macros/pearson_r.sql`

**Enne**:
```sql
--   SELECT ov_kood, {% raw %}{{ pearson_r(...) }}{% endraw %} AS r
```

**Pärast**:
```sql
--   SELECT ov_kood, {{ pearson_r('keskmine_temp', 'soojakadu_kwh_paevas') }} AS r
```

**Miks**: `{% raw %}...{% endraw %}` on Jinja silt, mis ütleb mootorile "ära töötle sisu". Makro kommentaaris on see kasutu ja segadust tekitav. Tõenäoliselt kopeerimisjääk dbt dokumentatsiooni generaatorist.

**Mõju**: Ainult kosmeetiline — kommentaar on nüüd puhas ja loetav.

---

## Lisatähelepanek (ei parandatud, sest pole koodiviga)

`dbt test` aeglus, millest kasutaja rääkis, ei ole `dbt test` enda probleem. `dbt test` jooksutab 3 lihtsat SQL päringut otse mart-tabelite peal — need on millisekundites. Tegelik aeglane osa on **`dbt run`**, mis enne `dbt test`-i materjaliseerib mart-tabelid:

```
[lae_*] >> dbt_build() [seed + run] >> dbt_test()
                              ↑
                     ~110M rida enne agregeerimist
                     (int_soojakadu vaade)
```

`int_soojakadu` on vaade, mis ristühendab ~300K hoonet ilmajaamade ja päevadega — see on arvutusmahukas ja seda käivitatakse iga `dbt run` käigus.

Olemasolevad testid on pealegi "vaakum-kindlad": kui mart-tabel on tühi (nt kui `int_soojakadu` andmeid pole), siis `WHERE r < -1 OR r > 1` tagastab 0 rida = test läbib. Arhitektuuris kirjeldatud andmekvaliteedi testid (tühjade väljade osakaal OV lõikes, `not_null`, `unique`) puuduvad.
