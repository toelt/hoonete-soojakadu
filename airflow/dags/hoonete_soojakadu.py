import csv
import subprocess
from datetime import date, datetime, timedelta, timezone

import requests
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.sdk import task

from airflow import DAG


@task
def lae_ehitisregister():
    """Laeb Ehitisregistri CSV andmebaasi (kui pole veel laetud)."""
    hook = PostgresHook(postgres_conn_id="analytics_db")

    hook.run("CREATE SCHEMA IF NOT EXISTS staging", autocommit=True)
    hook.run("""
        CREATE TABLE IF NOT EXISTS staging.ehitisregister_raw (
            ehr_kood        TEXT,
            esmane_kasutus  INTEGER,
            suletud_netopind NUMERIC(12, 2),
            ov_nimi         TEXT,
            energiamargis   TEXT,
            laetud_kell     TIMESTAMPTZ DEFAULT now()
        )
    """)

    already = hook.get_first("SELECT COUNT(*) FROM staging.ehitisregister_raw")[0]
    if already > 0:
        print(f"Andmed juba laetud ({already} rida).")
        return

    path = "/opt/airflow/data/ehitisregister.csv"
    print(f"Laadin: {path}")

    conn = hook.get_conn()
    cur = conn.cursor()
    loaded = 0

    with open(path, encoding="utf-8") as f:
        for row in csv.DictReader(f, delimiter=";"):
            a = row.get("esmane_kasutus", "").strip()
            p = row.get("suletud_netopind", "").strip()
            cur.execute(
                "INSERT INTO staging.ehitisregister_raw "
                "(ehr_kood, esmane_kasutus, suletud_netopind, ov_nimi, energiamargis) "
                "VALUES (%s, %s, %s, %s, %s)",
                (
                    row["ehr_kood"],
                    int(a) if a else None,
                    float(p) if p else None,
                    row["omavalitsus_nimetus"],
                    row["energia_klass"],
                ),
            )
            loaded += 1
            if loaded % 100000 == 0:
                conn.commit()
                print(f"  {loaded}...")
        conn.commit()

    cur.close()
    conn.close()
    print(f"Laetud: {loaded} rida.")


@task
def lae_ilmaandmed():
    """Laeb Open-Meteo ajaloolised tunniandmed 6 ilmajaama kohta.

    Kasutab Open-Meteo archive API-t tasuta limiidi piires (10k päringut/päev).
    6 jaama × 1 päring käivituse kohta = 6 päringut = 0.06% limiidist.
    Andmed salvestatakse staging.ilmaandmed_raw — inkrementaalne, UPSERT.
    """
    hook = PostgresHook(postgres_conn_id="analytics_db")

    hook.run("CREATE SCHEMA IF NOT EXISTS staging", autocommit=True)
    hook.run(
        """
        CREATE TABLE IF NOT EXISTS staging.ilmaandmed_raw (
            jaam_kood   TEXT NOT NULL,
            kuupaev     DATE NOT NULL,
            tund        SMALLINT NOT NULL,
            temperatuur NUMERIC(4, 1),
            loaded_at   TIMESTAMPTZ DEFAULT now(),
            PRIMARY KEY (jaam_kood, kuupaev, tund)
        )
        """,
        autocommit=True,
    )

    jaamad = [
        ("TLN", 59.437, 24.7535),  # Tallinn
        ("TRT", 58.378, 26.729),  # Tartu
        ("PRN", 58.386, 24.497),  # Pärnu
        ("NRV", 59.376, 28.191),  # Narva
        ("VRU", 57.848, 27.002),  # Võru
        ("KRS", 58.248, 22.490),  # Kuressaare
    ]

    today = date.today()
    total = 0

    for jaam_kood, lat, lon in jaamad:
        row = hook.get_first(
            "SELECT MAX(kuupaev) FROM staging.ilmaandmed_raw WHERE jaam_kood = %s",
            [jaam_kood],
        )

        if row and row[0]:
            start = row[0] + timedelta(days=1)
        else:
            start = date(2025, 1, 1)

        end = today - timedelta(days=1)

        if start > end:
            print(f"  {jaam_kood}: andmed juba olemas kuni {end}")
            continue

        print(f"{jaam_kood}: laadin {start} kuni {end} ...")

        url = "https://archive-api.open-meteo.com/v1/archive"
        params = {
            "latitude": lat,
            "longitude": lon,
            "start_date": start.isoformat(),
            "end_date": end.isoformat(),
            "timezone": "Europe/Tallinn",
            "hourly": "temperature_2m",
        }

        resp = requests.get(url, params=params, timeout=60)
        resp.raise_for_status()
        data = resp.json()

        hourly = data.get("hourly", {})
        times = hourly.get("time", [])
        temps = hourly.get("temperature_2m", [])

        inserted = 0
        conn = hook.get_conn()
        cur = conn.cursor()

        for t_str, temp in zip(times, temps):
            dt = datetime.fromisoformat(t_str)
            cur.execute(
                """
                INSERT INTO staging.ilmaandmed_raw
                    (jaam_kood, kuupaev, tund, temperatuur)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (jaam_kood, kuupaev, tund) DO NOTHING
                """,
                (
                    jaam_kood,
                    dt.date(),
                    dt.hour,
                    round(float(temp), 1) if temp is not None else None,
                ),
            )
            inserted += 1
            if inserted % 5000 == 0:
                conn.commit()
                print(f"  {jaam_kood}: {inserted} rida ...")

        conn.commit()
        cur.close()
        conn.close()
        total += inserted
        print(f"  {jaam_kood}: laetud {inserted} rida")

    print(f"Kokku laetud: {total} rida")


@task
def lae_tarbimine():
    """Laeb Elering API-st riikliku tunnitarbimise (MWh).

    API tagastab ~48 tundi tegelikke (real) ja prognoositud (plan) andmeid.
    Salvestame ainult real-andmed — inkrementaalne, UPSERT.
    """
    hook = PostgresHook(postgres_conn_id="analytics_db")

    hook.run("CREATE SCHEMA IF NOT EXISTS staging", autocommit=True)
    hook.run(
        """
        CREATE TABLE IF NOT EXISTS staging.tarbimine_raw (
            timestamp   TIMESTAMPTZ NOT NULL,
            tarbimine   NUMERIC(8, 2),
            loaded_at   TIMESTAMPTZ DEFAULT now(),
            PRIMARY KEY (timestamp)
        )
        """,
        autocommit=True,
    )

    url = "https://dashboard.elering.ee/api/system/with-plan"
    resp = requests.get(url, timeout=30)
    resp.raise_for_status()
    data = resp.json()

    if not data.get("success"):
        raise RuntimeError(f"Elering API viga: {data}")

    real_data = data.get("data", {}).get("real", [])
    if not real_data:
        print("Elering API ei tagastanud real-andmeid.")
        return

    inserted = 0
    conn = hook.get_conn()
    cur = conn.cursor()

    for entry in real_data:
        ts = entry["timestamp"]
        consumption = entry.get("consumption")
        cur.execute(
            """
            INSERT INTO staging.tarbimine_raw (timestamp, tarbimine)
            VALUES (%s, %s)
            ON CONFLICT (timestamp) DO NOTHING
            """,
            (
                datetime.fromtimestamp(ts, tz=timezone.utc),
                round(float(consumption), 2) if consumption is not None else None,
            ),
        )
        inserted += 1

    conn.commit()
    cur.close()
    conn.close()
    print(
        f"Laetud: {inserted} rida (viimane: {datetime.fromtimestamp(real_data[-1]['timestamp'], tz=timezone.utc)})"
    )


@task
def lae_elektrihinnad():
    """Laeb Elering/Nord Pool API-st Eesti börsielektri hinna (€/MWh).

    API tagastab ~48 tundi tunnihindu: data.ee[].timestamp + data.ee[].price.
    Salvestame ainult Eesti hinnad — inkrementaalne, UPSERT.
    """
    hook = PostgresHook(postgres_conn_id="analytics_db")

    hook.run("CREATE SCHEMA IF NOT EXISTS staging", autocommit=True)
    hook.run(
        """
        CREATE TABLE IF NOT EXISTS staging.elektrihinnad_raw (
            timestamp   TIMESTAMPTZ NOT NULL,
            hind        NUMERIC(6, 2),
            loaded_at   TIMESTAMPTZ DEFAULT now(),
            PRIMARY KEY (timestamp)
        )
        """,
        autocommit=True,
    )

    url = "https://dashboard.elering.ee/api/nps/price"
    resp = requests.get(url, timeout=30)
    resp.raise_for_status()
    data = resp.json()

    if not data.get("success"):
        raise RuntimeError(f"Nord Pool API viga: {data}")

    ee_data = data.get("data", {}).get("ee", [])
    if not ee_data:
        print("Nord Pool API ei tagastanud EE hindu.")
        return

    inserted = 0
    conn = hook.get_conn()
    cur = conn.cursor()

    for entry in ee_data:
        ts = entry["timestamp"]
        price = entry.get("price")
        cur.execute(
            """
            INSERT INTO staging.elektrihinnad_raw (timestamp, hind)
            VALUES (%s, %s)
            ON CONFLICT (timestamp) DO NOTHING
            """,
            (
                datetime.fromtimestamp(ts, tz=timezone.utc),
                round(float(price), 2) if price is not None else None,
            ),
        )
        inserted += 1

    conn.commit()
    cur.close()
    conn.close()
    print(
        f"Laetud: {inserted} rida (viimane: {datetime.fromtimestamp(ee_data[-1]['timestamp'], tz=timezone.utc)})"
    )


@task
def dbt_build():
    """Käivitab dbt seed + dbt run."""
    for cmd in (["dbt", "seed"], ["dbt", "run"]):
        result = subprocess.run(
            cmd + ["--profiles-dir", "/opt/airflow/dbt_project"],
            cwd="/opt/airflow/dbt_project",
            capture_output=True,
            text=True,
        )
        print(result.stdout)
        if result.returncode != 0:
            raise RuntimeError(result.stderr)


@task
def dbt_test():
    """Käivitab dbt test — kontrollib andmekvaliteeti pärast laadimist."""
    import time

    t0 = time.time()
    result = subprocess.run(
        ["dbt", "test", "--profiles-dir", "/opt/airflow/dbt_project"],
        cwd="/opt/airflow/dbt_project",
        capture_output=True,
        text=True,
    )
    elapsed = time.time() - t0
    print(f"[ajastus] dbt test kestis {elapsed:.1f}s")
    print(result.stdout)
    if result.stderr:
        print(f"dbt stderr: {result.stderr}")
    if result.returncode not in (0, 1):  # 0=OK, 1=hoiatused, 2+=vead
        raise RuntimeError(result.stderr or result.stdout)


with DAG(
    dag_id="hoonete_soojakadu",
    description="Ehitisregister CSV + Open-Meteo ilm + Elering tarbimine + Nord Pool hind → staging + dbt",
    schedule="@daily",
    start_date=datetime(2026, 1, 1, tzinfo=timezone.utc),
    catchup=False,
    tags=["sprint2"],
) as dag:
    (
        [lae_ehitisregister(), lae_ilmaandmed(), lae_tarbimine(), lae_elektrihinnad()]
        >> dbt_build()
        >> dbt_test()
    )
