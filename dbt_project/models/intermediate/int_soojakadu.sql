-- int_soojakadu: Soojakao arvutus iga hoone ja iga päeva kohta,
-- agregeeritult omavalitsuse ja päeva kaupa.
--
-- Valem: U × pindala × (21 − T_väljas) × 24h / 1000  →  kWh päevas
-- Arvutusmaht: ~300 000 hoonet × 365 päeva = ~110 miljonit rida enne agregeerimist.
-- PgDuckDB (DuckDB mootor) haldab seda mahtu veerupõhise täitmisplaaniga.
--
-- Sõltuvused:
--   stg_hooned       — peab sisaldama u_vaartus veergu
--   stg_ilmaandmed   — peab olema loodud (Open-Meteo API → staging.ilmaandmed_raw → stg_ilmaandmed)

WITH
hooned AS (
  SELECT
    ehr_kood,
    suletud_netopind,
    ov_nimi,
    ov_kood,
    u_vaartus
  FROM {{ ref('stg_hooned') }}
  WHERE u_vaartus IS NOT NULL
),

-- Päeva keskmine välistemperatuur ilmajaama kaupa.
-- Tulbad: kuupaev, jaam_kood, keskmine_temp
ilm AS (
  SELECT
    kuupaev,
    jaam_kood,
    keskmine_temp
  FROM {{ ref('stg_ilmaandmed') }}
  WHERE keskmine_temp IS NOT NULL
),

-- OV → ilmajaama vastendus.
-- 6 ilmajaama: TLN (Tallinn), TRT (Tartu), PRN (Pärnu), NRV (Narva), VRU (Võru), KRS (Kuressaare).
-- Omavalitsused on jaotatud maakondliku asukoha järgi lähimasse ilmajaama.
-- TODO: asenda seed-tabeliga (ov_jaam.csv), et vastendus oleks hallatav, testitav ja versioneeritav.
ov_jaam AS (
  SELECT * FROM (VALUES
    -- Harjumaa → Tallinn (TLN)
    ('0130', 'TLN'),  -- Anija vald
    ('0191', 'TLN'),  -- Harku vald
    ('0214', 'TLN'),  -- Jõelähtme vald
    ('0320', 'TLN'),  -- Keila linn
    ('0354', 'TLN'),  -- Kiili vald
    ('0393', 'TLN'),  -- Kose vald
    ('0409', 'TLN'),  -- Kuusalu vald
    ('0430', 'TLN'),  -- Loksa linn
    ('0441', 'TLN'),  -- Lääne-Harju vald
    ('0478', 'TLN'),  -- Maardu linn
    ('0651', 'TLN'),  -- Raasiku vald
    ('0698', 'TLN'),  -- Rae vald
    ('0725', 'TLN'),  -- Saue vald
    ('0806', 'TLN'),  -- Saku vald
    ('0865', 'TLN'),  -- Tallinn
    ('0890', 'TLN'),  -- Viimsi vald
    -- Raplamaa põhjaosa → Tallinn (TLN) — geograafiliselt Tallinna kliimavööndis
    ('0365', 'TLN'),  -- Kohila vald
    -- Lääne-Virumaa → Tallinn (TLN)
    ('0184', 'TLN'),  -- Haljala vald
    ('0255', 'TLN'),  -- Kadrina vald
    ('0707', 'TLN'),  -- Rakvere linn
    ('0714', 'TLN'),  -- Rakvere vald
    ('0882', 'TLN'),  -- Tapa vald
    ('0996', 'TLN'),  -- Vinni vald
    ('1007', 'TLN'),  -- Viru-Nigula vald
    ('1053', 'TLN'),  -- Väike-Maarja vald
    -- Ida-Virumaa → Narva (NRV)
    ('0120', 'NRV'),  -- Alutaguse vald
    ('0232', 'NRV'),  -- Jõhvi vald
    ('0372', 'NRV'),  -- Kohtla-Järve linn
    ('0465', 'NRV'),  -- Lüganuse vald
    ('0557', 'NRV'),  -- Narva linn
    ('0560', 'NRV'),  -- Narva-Jõesuu linn
    ('0834', 'NRV'),  -- Sillamäe linn
    ('0918', 'NRV'),  -- Toila vald
    -- Tartumaa → Tartu (TRT)
    ('0160', 'TRT'),  -- Elva vald
    ('0272', 'TRT'),  -- Kambja vald
    ('0296', 'TRT'),  -- Kastre vald
    ('0579', 'TRT'),  -- Nõo vald
    ('0897', 'TRT'),  -- Tartu linn
    ('0901', 'TRT'),  -- Tartu vald
    -- Jõgevamaa → Tartu (TRT)
    ('0225', 'TRT'),  -- Jõgeva vald
    ('0502', 'TRT'),  -- Mustvee vald
    ('0619', 'TRT'),  -- Peipsiääre vald
    ('0641', 'TRT'),  -- Põltsamaa vald
    -- Järvamaa → Tartu (TRT)
    ('0249', 'TRT'),  -- Järva vald
    ('0606', 'TRT'),  -- Paide linn
    ('0955', 'TRT'),  -- Türi vald
    -- Viljandimaa → Tartu (TRT)
    ('0490', 'TRT'),  -- Mulgi vald
    ('0638', 'TRT'),  -- Põhja-Sakala vald
    ('0972', 'TRT'),  -- Viljandi linn
    ('0983', 'TRT'),  -- Viljandi vald
    -- Põlvamaa → Võru (VRU)
    ('0283', 'VRU'),  -- Kanepi vald
    ('0655', 'VRU'),  -- Põlva vald
    ('0708', 'VRU'),  -- Räpina vald
    -- Võrumaa → Võru (VRU)
    ('0141', 'VRU'),  -- Antsla vald
    ('0761', 'VRU'),  -- Rõuge vald
    ('0823', 'VRU'),  -- Setomaa vald
    ('1035', 'VRU'),  -- Võru linn
    ('1046', 'VRU'),  -- Võru vald
    -- Valgamaa → Võru (VRU)
    ('0590', 'VRU'),  -- Otepää vald
    ('0857', 'VRU'),  -- Valga vald
    ('0940', 'VRU'),  -- Tõrva vald
    -- Pärnumaa → Pärnu (PRN)
    ('0193', 'PRN'),  -- Häädemeeste vald
    ('0337', 'PRN'),  -- Kihnu vald
    ('0624', 'PRN'),  -- Põhja-Pärnumaa vald
    ('0670', 'PRN'),  -- Pärnu linn
    ('0780', 'PRN'),  -- Saarde vald
    ('0929', 'PRN'),  -- Tori vald
    -- Läänemaa → Pärnu (PRN)
    ('0170', 'PRN'),  -- Haapsalu linn
    ('0447', 'PRN'),  -- Lääne-Nigula vald
    ('0452', 'PRN'),  -- Lääneranna vald
    -- Raplamaa lõunaosa → Pärnu (PRN)
    ('0303', 'PRN'),  -- Kehtna vald
    ('0528', 'PRN'),  -- Märjamaa vald
    ('0735', 'PRN'),  -- Rapla vald
    -- Saaremaa → Kuressaare (KRS)
    ('0483', 'KRS'),  -- Muhu vald
    ('0750', 'KRS'),  -- Ruhnu vald
    ('0793', 'KRS'),  -- Saaremaa vald
    -- Hiiumaa → Kuressaare (KRS)
    ('0198', 'KRS'),  -- Hiiumaa vald
    -- Läänemaa saared → Kuressaare (KRS)
    ('1018', 'KRS')   -- Vormsi vald
  ) AS t(ov_kood, jaam_kood)
),

-- Soojakadu iga hoone ja iga päeva kohta:
--   U (W/m²K) × pindala (m²) × (21 − T_väljas) (K) × 24 (h) / 1000 (W→kW)
--   = kWh päevas
-- GREATEST(..., 0) väldib negatiivset soojakadu, kui T_väljas >= 21 °C.
hoone_paeva_kadu AS (
  SELECT
    h.ehr_kood,
    h.ov_kood,
    h.ov_nimi,
    h.suletud_netopind,
    i.kuupaev,
    i.keskmine_temp,
    h.u_vaartus
      * h.suletud_netopind
      * GREATEST(21 - i.keskmine_temp, 0)
      * 24 / 1000.0 AS soojakadu_kwh
  FROM hooned h
  JOIN ov_jaam oj ON h.ov_kood = oj.ov_kood
  JOIN ilm i     ON oj.jaam_kood = i.jaam_kood
)

-- Agregeerimine OV ja päeva kaupa
SELECT
  ov_kood,
  ov_nimi,
  kuupaev,
  MAX(keskmine_temp)        AS keskmine_temp,
  COUNT(DISTINCT ehr_kood)  AS hoonete_arv,
  SUM(suletud_netopind)     AS kogupindala_m2,
  SUM(soojakadu_kwh)        AS soojakadu_kwh_paevas
FROM hoone_paeva_kadu
GROUP BY ov_kood, ov_nimi, kuupaev
