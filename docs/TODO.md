# TODO — `arhitektuur.md` vs tegelik koodibaas

Loodud: 2026-06-05  
Viimati uuendatud: 2026-06-05

---

## 🟢 Valmis

| Komponent | Fail |
|-----------|------|
| Docker Compose (Airflow + Superset + pgDuckDB) | `compose.yml` |
| `staging.ehitusregister_raw` laadimine (Airflow DAG) | `airflow/dags/hoonete_soojakadu.py` |
| `stg_hooned` — puhastamine, dedup, OV normaliseerimine, U-väärtuse lookup | `dbt_project/models/staging/stg_hooned.sql` |
| `omavalitsused.csv` seed | `dbt_project/seeds/omavalitsused.csv` |
| `omavalitsus_mapping.csv` seed (2017 reformi vastendus) | `dbt_project/seeds/omavalitsus_mapping.csv` |
| `u_vaartused.csv` seed — 12 ehitusperioodi U-väärtused | `dbt_project/seeds/u_vaartused.csv` |
| `u_vaartus` makro — CASE WHEN lookup ehitusaasta järgi | `dbt_project/macros/u_vaartus.sql` |
| `int_soojakadu` — soojakao arvutus OV × päev, OV→ilmajaam vastendus | `dbt_project/models/intermediate/int_soojakadu.sql` |
| `dbt_build()` DAG task (seed + run) | `airflow/dags/hoonete_soojakadu.py` |
| `dbt_test()` DAG task (peale build-i) | `airflow/dags/hoonete_soojakadu.py` |
| `sources.yml` — `ehitisregister_raw.ehr_kood` test | `dbt_project/models/staging/sources.yml` |
| Staging testid (`stg_hooned`, `stg_ilmaandmed`, `stg_elektrihinnad`, `stg_tarbimine`) | `dbt_project/models/staging/schema.yml` |
| Intermediate testid (`int_soojakadu`) | `dbt_project/models/intermediate/schema.yml` |
| Mart testid (4 mudelit) | `dbt_project/models/marts/schema.yml` |
| Generictestid `positive_value` ja `not_negative` | `dbt_project/macros/test_positive_value.sql`, `test_not_negative.sql` |
| Singulartestid Pearsoni r ja R² vahemike jaoks | `dbt_project/tests/` (3 faili) |
| `.env` + `.gitignore` | juur |
| Intermediate kiht `dbt_project.yml`-is | `dbt_project/dbt_project.yml` |

---

## 🔴 Kriitilised puudujäägid (blokeerivad põhiloogikat)

### 1. Open-Meteo API integratsioon

- `airflow/dags/open_meteo.py` on testimisskript, mitte Airflow DAG task.
- **Vaja**:
  - DAG task (või eraldi DAG), mis korjab 6 ilmajaama tunnitemperatuurid Open-Meteo API-st.
  - Salvestada `staging.ilmaandmed_raw` (UPSERT, `loaded_at`).
  - dbt `stg_ilmaandmed` vaade toortabeli peale.
- **6 ilmajaama**: Tallinn, Tartu, Pärnu, Narva, Võru, Kuressaare.
- **Risk**: API limiit 10k päringut/päev → 6 päringut/päev = 0.06% (ohutu).

### 2. Elering — tarbimine API integratsioon

- Riiklik tunnitarbimine puudub täielikult.
- **Vaja**:
  - DAG task `nps/price` API-st.
  - Salvestada `staging.tarbimine_raw`.
  - dbt `stg_tarbimine` vaade.
- **Vajalik**: mudeli valideerimiseks (`mart_mudeli_valideerimine`).

### 3. Elering — Nord Pool API integratsioon

- Börsielektri hind puudub täielikult.
- **Vaja**:
  - DAG task `nps/price` API-st.
  - Salvestada `staging.elektrihinnad_raw`.
  - dbt `stg_elektrihinnad` vaade.
- **Vajalik**: renoveerimispotentsiaali € arvutuseks (`mart_renoveerimise_potentsiaal`).

### 4. `stg_ilmaandmed` vaade

- Sõltub punktist 1 (Open-Meteo API).
- Vaja `dbt_project/models/staging/stg_ilmaandmed.sql`.
- Tulbad: `kuupaev`, `jaam_kood`, `keskmine_temp`.

### 5. `stg_tarbimine` vaade

- Sõltub punktist 2 (Elering tarbimine).
- Vaja `dbt_project/models/staging/stg_tarbimine.sql`.

### 6. `stg_elektrihinnad` vaade

- Sõltub punktist 3 (Nord Pool).
- Vaja `dbt_project/models/staging/stg_elektrihinnad.sql`.

### 7. `pearson_r` makro

- Vajalik `mart_ilmastikutundlikkus` ja `mart_mudeli_valideerimine` jaoks.
- Vaja `dbt_project/macros/pearson_r.sql`.
- Pearsoni korrelatsioonikordaja arvutus: `CORR(x, y)` või käsitsi implementatsioon.

### 8. Mart-kihi mudelid (kõik 4 puudu)

| Mudel | Kirjeldus | Sõltub |
|-------|-----------|--------|
| `marts.mart_soojakadu_ov` | Soojakao intensiivsus (kWh/m²/aastas) OV kaupa | `int_soojakadu` |
| `marts.mart_ilmastikutundlikkus` | Pearsoni r temperatuuri ja soojakao vahel | `int_soojakadu` + `pearson_r` |
| `marts.mart_renoveerimise_potentsiaal` | Säästupotentsiaal € | `int_soojakadu` + `stg_elektrihinnad` |
| `marts.mart_mudeli_valideerimine` | Mudeli täpsuse võrdlus tegeliku tarbimisega | `int_soojakadu` + `stg_tarbimine` + `pearson_r` |

### 9. `dim_omavalitsus` snapshot

- Arhitektuuris `snapshots.dim_omavalitsus` (SCD Type 2) — puudub.
- `snapshots/` kataloogi pole loodud.
- Alternatiiv: kasutada lihtsalt `omavalitsused` seed'i, kui ajaloolisi muutusi pole vaja.

---

## 🟡 Olulised, aga mitte blokeerivad

### ~~10. `dbt test` integratsioon~~ ✅ Valmis

- 60 testi üle kõigi kihtide (sources, staging, intermediate, marts).
- Kasutatakse nii standardteste (`not_null`, `unique`, `accepted_values`) kui kohandatud genericteste (`positive_value`, `not_negative`) ja singularteste (Pearsoni r vahemik).
- `dbt_test()` task lisatud DAG-i — jookseb automaatselt peale `dbt_build`-i.
- `mart_mudeli_valideerimine` testid on `severity: warn` — aktiveeruvad kui ilma- ja tarbimisandmete perioodid joonduvad.

### 11. `staging` sources.yml on puudulik

- Ainult `ehitisregister_raw` defineeritud.
- **Vaja lisada**: `ilmaandmed_raw`, `tarbimine_raw`, `elektrihinnad_raw`.

### 12. DAG ajakava

- Praegu `@once`. Arhitektuur näeb ette tunnipõhist/inkrementaalset laadimist.
- **Vaja**: regulaarne schedule (nt `@hourly`) ja inkrementaalsed laadimismustrid.

### 13. Inkrementaalne laadimine (UPSERT + `loaded_at`)

- Ehitisregister: laetud `INSERT`-ina ilma idempotentsuseta.
- API allikad peaksid kasutama `UPSERT` koos `loaded_at` ajatempliga.
- **Vaja**: uuendada laadimisloogikat.

### 14. Arvutusoptimeerimise disainiotsus

- Arhitektuur: ~300k hoonet × 8760 tundi ≈ 2.6 miljardit rida.
- Praegune `int_soojakadu` kasutab **päevast** agregeerimist (~110M rida). See on kooskõlas arhitektuuri riskimaandusega ("päevane täpsus on piisav").
- Kui on vaja tunnipõhist detailsust, tuleb `stg_ilmaandmed` ja `int_soojakadu` ümber teha.

### 15. OV → ilmajaama vastendus

- Praegu kõvakodeeritud `int_soojakadu` mudeli sees (`ov_jaam` CTE).
- **Soovitatav**: asendada seed-tabeliga `seeds/ov_jaam.csv`, et vastendus oleks hallatav ja testitav.

---

## 🟢 Kosmeetilised / Nice-to-have

| Teema | Detail |
|-------|--------|
| `mart_ehitusaastad` + `mart_hooned_ov` | Prototüübi mudelid, pole arhitektuuris. Võib säilitada abimudelitena. |
| `README.md` | Ainult autorite nimed — vaja täiendada setup juhistega. |
| `init/` kataloog | Tühi — mõeldud `analytics-db` initsialiseerimisskriptidele. |
| `.env.example` | Puudub (vajalik uutele arendajatele). |
| Superset ühendamine `analytics-db`-ga | Dashboardi loomine OV soojakao, ilmastikutundlikkuse ja renoveerimispotentsiaali jaoks. |

---

## Soovitatav tööde järjekord

| # | Ülesanne | Roll (arhitektuuri järgi) |
|---|----------|--------------------------|
| 1 | Open-Meteo API → `staging.ilmaandmed_raw` DAG task + `stg_ilmaandmed` | Toel (API) + Erkki (dbt) |
| 2 | Elering tarbimine API → `staging.tarbimine_raw` + `stg_tarbimine` | Toel + Erkki |
| 3 | Elering Nord Pool API → `staging.elektrihinnad_raw` + `stg_elektrihinnad` | Toel + Erkki |
| 4 | `pearson_r` makro | Erkki |
| 5 | `mart_soojakadu_ov` | Erkki |
| 6 | `mart_ilmastikutundlikkus` | Erkki |
| 7 | `mart_renoveerimise_potentsiaal` | Erkki |
| 8 | `mart_mudeli_valideerimine` | Erkki |
| 9 | `dim_omavalitsus` snapshot (või otsus seed-i kasuks) | Erkki |
| 10 | `dbt test` definitsioonid + DAG task | Mihkel |
| 11 | DAG schedule muutmine + inkrementaalne laadimine | Toel |
| 12 | `sources.yml` uuendamine kõigi toortabelitega | Erkki |
| 13 | `ov_jaam.csv` seed (asendab kõvakodeeritud CTE) | Erkki |
| 14 | Superset dashboard | Anna-Liisa |
