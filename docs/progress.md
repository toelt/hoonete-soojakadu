## Voog 1: Ehitisregister — hoonete statistika

### Samm 1.1: Docker Compose käivitamine

```bash
cd hoonete-soojakadu
docker compose up -d --build
```

Oota 2–3 minutit, kuni kõik teenused on valmis:

```bash
docker compose ps
```

Kõk konteinerid peavad olema `healthy` või `Up`.

### Samm 1.2: Airflow DAG käivitamine  

### Samm 1.3: Kontrolli, kas Ehitisregistri andmed laeti

Puhastatud andmestik peaks olema väiksem kui toorandmestik (välja filtreeritud hooned, kus puudub ehitusaasta või pindala).

### Samm 1.5: Loome lihtsad omavalitsuste agregaadid (SQL Lab päringud)

**Päring 1: Hoonete arv omavalitsuse kaupa**


**Päring 2: Hoonete keskmine ehitusaasta omavalitsuse kaupa**


**Päring 3: Hoonete kogupindala omavalitsuse kaupa**


**Päring 4: Ehitusaastate jaotus (histogramm)**


### Samm 1.6: Superset visuaalid

**Visuaal 1: Hoonete arv omavalitsuse kaupa (tulpdiagramm)**

**Visuaal 2: Keskmine ehitusaasta omavalitsuse kaupa (tulpdiagramm)**

**Visuaal 3: Ehitusaastate jaotus (histogramm)**
