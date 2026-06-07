# Hoonete soojakadu ja renoveerimisprioriteedid

**Andmeinseneeria kursuse grupitöö**

Anna-Liisa Altmets · Erkki Laaneoks · Mihkel Nugis · Toel Teemaa

---

## Mida me uurisime?

Eesti hoonefond on vana — suur osa elamuid on ehitatud nõukogude ajal, mil soojustus jättis soovida. Küte läheb läbi halbade seinte ja katuste kaduma, mis tähendab nii kõrgemaid energiaarved elanikele kui ka suuremat CO₂ jalajälge.

**Meie küsimus:** millistes Eesti omavalitsustes kaotavad hooned kõige rohkem soojusenergiat ja kus oleks renoveerimine kõige suurema mõjuga?

Vastuse leidmiseks ühendame kolm andmeallikat:
- **Ehitisregister** (~300 000 hoonet koos ehitusaasta ja pindalaga)
- **Ilmaandmed** (iga päeva keskmised temperatuurid 6 ilmajaamast üle Eesti)
- **Elektrihind** (Eleringi Nord Pool börsihind — et soojakao saaks eurodes väljendada)

---

## Kuidas see töötab?

Soojakadu arvutatakse füüsikalise valemi järgi:

> **Soojakadu (kWh) = U-väärtus × pindala × (21°C − õhutemperatuur) × 24h**

Kus **U-väärtus** näitab, kui hästi hoone soojust peab — vanem hoone = suurem U = rohkem kadu. Mida külmem õues ja mida vanem hoone, seda rohkem soojusenergiat läheb raisku.

Arvutus tehakse iga hoone ja iga päeva kohta ning agregeeritakse omavalitsuse tasemele.

---

## Tulemused

Analüüs annab neli mõõdikut omavalitsuste kaupa:

| Mõõdik | Kirjeldus |
|--------|-----------|
| **Soojakao intensiivsus** | kWh/m²/aastas — mida suurem, seda halvem |
| **Ilmastikutundlikkus** | Pearsoni korrelatsioon: kui tugevalt sõltub soojakadu temperatuurist |
| **Renoveerimispotentsiaal** | Potentsiaalne aastane kokkuhoid eurodes, kui viia intensiivsus 50 kWh/m²-ni |
| **Mudeli valideerimine** | Mudeli soojakadu vs. tegelik Eleringi tarbimine — kui täpne mudel on |

---

## Tehniline ülesehitus

Projekt kasutab kaasaegset andmetöötluse tarneahelat:

```
Andmeallikad → Airflow (laadimine) → PostgreSQL → dbt (teisendamine) → Superset (visualiseerimine)
```

**Airflow** käivitab iga päev andmete laadimise: ehitisregistri CSV, ilmaandmed Open-Meteo API-st ja elektrihinnad Eleringi API-st.

**dbt** teisendab toortabelid kolmes kihis:
- *Staging* — andmete puhastamine ja normaliseerimine
- *Intermediate* — soojakao arvutus (~110 miljonit rida enne agregeerimist)
- *Marts* — lõplikud analüütilised tabelid Superseti jaoks

**Andmekvaliteedi testid** (dbt test) kontrollivad automaatselt peale iga laadimist, et arvutuste sisendandmed oleksid korrektsed — puuduvad väärtused, lubatute vahemikust väljas arvud, matemaatilised invariandid (nt Pearsoni r ∈ [-1, 1]).

**Superset** kuvab tulemused interaktiivse kaardina ja graafikutena.

Kogu keskkond töötab **Dockeris** — ühe käsuga saab kõik teenused käima.

---

## Käivitamine

**Eeldused:** Docker Desktop paigaldatud ja töötab.

### 0. Laadi alla toorandmed

Ehitisregistri CSV-fail ei ole giti osa (liiga suur). Laadi see alla Google Drive'ist ja aseta projekti `data/` kausta:

**[ehitisregister.csv — Google Drive](https://drive.google.com/drive/folders/1ro1HNSEUz7by02e8KY5kKwPg-7PHQHEe?usp=share_link)**

```
data/
└── ehitisregister.csv   ← pane siia
```

```bash
# 1. Kopeeri keskkonnamuutujate näidisfail
cp .env.example .env

# 2. Käivita kõik teenused
docker compose up -d

# 3. Ava Airflow (kasutaja/parool: .env failist)
#    http://localhost:8080
#    → käivita DAG "hoonete_soojakadu"

# 4. Ava Superset
#    http://localhost:8088
```

### Superseti dashboard import

Dashboardi fail asub `superset/dashboards/dashboard_export_20260607T133641.zip`.

1. **Dashboards → + → Import dashboard** → vali ZIP-fail
2. Pärast importi mine **Settings → Database Connections → `projekt_hooned` → Edit**
3. Uuenda parool URI-s (`XXXXXXXXXX` → `projekt`):
   ```
   postgresql+psycopg2://projekt:projekt@analytics-db:5432/projekt
   ```
4. **Test Connection** → **Save**

Airflow DAG teeb järjekorras:
1. Laadib ehitisregistri, ilmaandmed, elektrihinnad ja tarbimise
2. Käivitab `dbt build` (seed + run) — ehitab kõik mudelid
3. Käivitab `dbt test` — kontrollib andmekvaliteeti

---

## Projekti struktuur

```
├── airflow/dags/        # Andmete laadimise loogika (Airflow DAG)
├── dbt_project/
│   ├── models/
│   │   ├── staging/     # Andmete puhastamine (+ testid schema.yml-is)
│   │   ├── intermediate/# Soojakao arvutus
│   │   └── marts/       # Lõplikud analüütilised tabelid (+ testid)
│   ├── macros/          # Taaskasutatav loogika (pearson_r, u_vaartus, testid)
│   ├── seeds/           # Viitetabelid (omavalitsused, U-väärtused)
│   └── tests/           # Singulartestid äriloogika kontrollimiseks
├── docs/                # Arhitektuur, andmekirjeldus, TODO
├── superset/            # Supersetikonfiguratsioon
└── compose.yml          # Docker Compose
```

---

## Tööjaotus

| Nimi | Roll |
|------|------|
| **Toel Teemaa** | Andmete laadimine — Airflow DAG-id, API integratsioonid |
| **Erkki Laaneoks** | Teisendused — dbt mudelid, soojakao arvutus, mart-kiht |
| **Mihkel Nugis** | Andmekvaliteet — dbt testid, vigade diagnoos |
| **Anna-Liisa Altmets** | Visualiseerimine — Superset näidikulaud |

---

## Esitlus

[docs/esitlus.pptx](docs/esitlus.pptx)
