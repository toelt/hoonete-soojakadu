import csv
import subprocess
from datetime import datetime, timezone

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


with DAG(
    dag_id="hoonete_soojakadu",
    description="Ehitisregister CSV → staging + dbt puhastus",
    schedule="@once",
    start_date=datetime(2026, 1, 1, tzinfo=timezone.utc),
    catchup=False,
    tags=["sprint2"],
) as dag:
    lae_ehitisregister() >> dbt_build()
