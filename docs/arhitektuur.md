## Äriküsimus
Millistes Eesti omavalitsustes on hooned külmale kõige haavatavamad ning kus oleks renoveerimine kõige suurema energiasäästu potentsiaaliga?

## Mõõdikud
1. Soojakao intensiivsus (kWh/m²/aastas)
2. Ilmastikutundlikkuse indeks (Pearsoni r)
3. Renoveerimise potentsiaal (€)
4. Mudeli valideerimine (Pearsoni r + KAV)

## Andmeallikad
| Allikas | Tüüp | Sagedus | Roll |
|---------|------|---------|------|
| [Ehitisregister](https://livekluster.ehr.ee/ui/ehr/v1/infoportal/buildingdata) | CSV (staatiline) | Ühekordne | ~300000 hoonet — ehitusaasta, pindala, asukoht |
| [Open-Meteo](https://open-meteo.com) | REST API | Tunnipõhine | Välistemperatuur 6 ilmajaamast |
| [Elering — tarbimine](https://dashboard.elering.ee/api/system/with-plan) | REST API | Tunnipõhine, inkrementaalne | Tegelik riiklik tunnitarbimine (MWh) |
| [Elering — Nord Pool](https://dashboard.elering.ee/api/nps/price) | REST API | Päevapõhine | Eesti börsielektri hind (€/MWh) |

## Andmevoog

## Andmebaasi kihid

| Kiht | Roll |
|------|------|
| `staging` | Hoiab allika andmeid töötlemata kujul. |
| `mart` | Hoiab transformeeritud ja äriloogikat sisaldavaid tabeleid. |

## Tööjaotus

| Roll | Vastutus | Täitja |
|------|----------|--------|
| Andmeallika omanik | Kirjutab sissevõtu loogika, hoiab API-t töös | [Nimi] |
| Transformatsioonide omanik | Kirjutab mart kihi mudelid ja mõõdikute arvutuse | [Nimi] |
| Kvaliteedi omanik | Kirjutab testid ja vaatab läbi ebaõnnestunud kontrollid | [Nimi] |
| Näidikulaua omanik | Ehitab näidikulaua ja seob selle äriküsimusega | [Nimi] |

## Riskid

## Privaatsus ja turve

Kõik kasutatavad andmed on avalikud.
Andmebaasi ja API paroolid salvestatud .env failis.
.env fail on deklareeritud .gitingore's.
