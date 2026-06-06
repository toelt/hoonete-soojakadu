# Parandused — koodibaasi ülevaatus (2026-06-06)

---

## 1. `int_soojakadu.sql` — `::integer` cast on vajalik (rida 156), esialgne "parandus" oli ekslik ja tühistatud

**Fail**: `dbt_project/models/intermediate/int_soojakadu.sql`

**Algne kood (töötav)** :
```sql
JOIN ov_jaam oj ON h.ov_kood = oj.ov_kood::integer
```

**Miks cast on vajalik**: DuckDB inferis `omavalitsused.csv` seedist `ov_kood` INTEGER-iks (`'0120'` → `120`). Seega `stg_hooned.ov_kood` = `COALESCE(o.ov_kood, '0000')` on INTEGER (DuckDB koertseerib `'0000'` → `0`). `ov_jaam` CTE VALUES (`('0130', 'TLN')`) on aga TEXT. `::integer` teisendab TEXT-i INTEGER-iks, et JOIN toimiks.

**Mõju**: JOIN töötab korrektselt — INTEGER = INTEGER.

> ⚠️ Esialgne ülevaatus tuvastas selle ekslikult "mittevajaliku castina" ja eemaldas selle — tagajärg: `operator does not exist: integer = text`. Cast on taastatud.

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

## 3. `pearson_r.sql` — `{{ }}` makro kommentaaris põhjustas lõpmatu rekursiooni (rida 6)

**Fail**: `dbt_project/macros/pearson_r.sql`

**Enne**:
```sql
  --   SELECT ov_kood, {{ pearson_r('keskmine_temp', 'soojakadu_kwh_paevas') }} AS r
```

**Pärast**:
```sql
  --   SELECT ov_kood, pearson_r('keskmine_temp', 'soojakadu_kwh_paevas') AS r
```

**Miks**: Jinja töötleb `{{ }}` plokke **igas kontekstis**, kaasa arvatud SQL-kommentaaride sees. Kuna see rida asus `pearson_r` makro definitsiooni sees, kutsus Jinja makrot rekursiivselt iseennast välja — `maximum recursion depth exceeded`.

Algne `{% raw %}...{% endraw %}` kaitses seda — see käskis Jinja-l sisu ignoreerida. Lihtsam lahendus: eemaldada `{{ }}` kommentaarist — dokumentatsioon on endiselt arusaadav ilma Jinja süntaksita.

**Mõju**: `dbt run` ja `dbt test` kompileeruvad nüüd veatult.

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
