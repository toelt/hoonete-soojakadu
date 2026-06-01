# Andmebaasi kihid

Andmebaas on jagatud neljaks analüütiliseks kihiks, mida haldab dbt, lisaks snapshots:

| Skeem | Materialiseeritus | Roll |
|--------|---------------|---------|
| **`staging`** | Toortabelid | Sisestatud lähteandmed (CSV, API päringud) — toorkujul |
| **`staging`** (dbt vaated) | Vaated | Puhastatud ja normaliseeritud vaated (nt `stg_hooned`) |
| **`marts`** | Tabelid | Lõplikud analüütilised tabelid Superset-i näidikulaudade jaoks |
| **Snapshots** (dbt) | Tabelid | Aeglaselt muutuvate dimensioonide jälgimine (nt `dim_omavalitsus`) |

---

## Andmed tabelite kaupa

### 1. `staging.ehitisregister_raw` (toorandmete sisestustabel)

Laetud Eesti **Ehitisregistri** CSV-failist (~300 000 rida). Tegemist on ühekordse staatilise laadimisega.

| Veerg | Tüüp | Kirjeldus |
|--------|------|-------------|
| `ehr_kood` | TEXT | Unikaalne ehitise registrikood (PK) |
| `esmane_kasutus` | INTEGER | Esmase kasutuse aasta / ehitusaasta |
| `suletud_netopind` | NUMERIC(12,2) | Suletud netopind (m²) |
| `ov_nimi` | TEXT | Omavalitsuse nimi |
| `energiamargis` | TEXT | Energiamärgise klass |
| `laetud_kell` | TIMESTAMPTZ | Laadimise ajatempel |

### 2. `staging.stg_hooned` (dbt vaade)

Puhastatud vaade, mis on ehitatud `ehitisregister_raw` peale:

- **Filtreerimine**: Ainult hooned, millel on korrektne ehitusaasta (1800–2026), positiivne netopind (< 100 000 m²) ja määratud omavalitsus.
- **Duplikaatide eemaldamine**: `DISTINCT ON (ehr_kood)` eemaldab duplikaadid, eelistades suurima pindalaga kirjet (tõenäoliselt põhihoone).
- **Nime normaliseerimine**: Ühendatakse `omavalitsus_mapping` tabeliga, et teisendada vanad (enne 2017) omavalitsuste nimed uutele.
- **Omavalitsuse koodi otsing**: Ühendatakse `omavalitsused` seed-tabeliga, et lisada standardiseeritud EHAK kood.

| Veerg | Kirjeldus |
|--------|-------------|
| `ehr_kood` | Ehitise ID |
| `ehitusaasta` | Ehitusaasta |
| `suletud_netopind` | Netopind (m²) |
| `ov_nimi` | Omavalitsuse nimi |
| `energiamargis` | Energiamärgis (puhastatud) |
| `ov_kood` | Standardiseeritud omavalitsuse kood |

### 3. `marts.mart_hooned_ov` (analüütiline tabel)

Agregeeritud hoonete statistika **omavalitsuse kaupa**:

| Veerg | Kirjeldus |
|--------|-------------|
| `ov_kood` | Omavalitsuse kood |
| `ov_nimi` | Omavalitsuse nimi |
| `hoonete_arv` | Hoonete koguarv |
| `kogupindala_m2` | Kogu netopind (m²) |
| `keskmine_pindala_m2` | Keskmine hoone pindala |
| `keskmine_ehitusaasta` | Keskmine ehitusaasta |
| `vanu_hooneid` | Enne 1960. aastat ehitatud hoonete arv |
| `margisega_hooneid` | Energiamärgisega hoonete arv |

### 4. `marts.mart_ehitusaastad` (analüütiline tabel)

Ehitusaastate jaotus agregeerituna **kümnendite kaupa**:

| Veerg | Kirjeldus |
|--------|-------------|
| `aastakymme` | Kümnend (nt 1970, 1980, ...) |
| `hoonete_arv` | Hoonete arv selles kümnendis |
| `kogupindala_m2` | Kogu netopind selles kümnendis |

### 5. Seed-tabel: `marts.omavalitsused` (CSV seed-failist)

Viitetabel, mis seob Eesti omavalitsuste nimed standardiseeritud koodidega (79 omavalitsust). Kasutatakse `stg_hooned` vaates omavalitsuse andmete normaliseerimiseks.

| Veerg | Kirjeldus |
|--------|-------------|
| `ov_kood` | Standardiseeritud omavalitsuse EHAK kood |
| `ov_nimi` | Omavalitsuse nimi (2017 haldusreformi järgne) |

### 6. Seed-tabel: `marts.omavalitsus_mapping` (CSV seed-failist)

Vastendustabel, mis seob ehitisregistris esinevad vanad omavalitsuste nimed (enne 2017. aasta haldusreformi) uute nimede külge. Eesti haldusreform 2017 liitis ~213 omavalitsust 79-ks — ehitisregistris esinevad mõlema ajastu nimed.

`stg_hooned` normaliseerib `ov_nimi` väärtuse läbi selle tabeli enne joini `omavalitsused` tabeliga. Kui vana nime vastet ei leita, kasutatakse originaalnime (mis võib olla juba uus nimi).

| Veerg | Kirjeldus |
|--------|-------------|
| `vana_nimi` | Omavalitsuse nimi ehitisregistris (enne 2017 reformi) |
| `uus_nimi` | Vastav omavalitsuse nimi pärast 2017 haldusreformi |
