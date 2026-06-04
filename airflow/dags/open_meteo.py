import openmeteo_requests

import pandas as pd
import requests_cache
from retry_requests import retry

#Sea Open-Meteo API kliendile koos puhverduse ja uuesti proovimisega, kui viga
cache_session = requests_cache.CachedSession('.cache', expire_after = 3600)
retry_session = retry(cache_session, retries = 5, backoff_factor = 0.2)
openmeteo = openmeteo_requests.Client(session = retry_session)

#Tallinna kohta info saamine hetkeinfo kohta
url = "https://api.open-meteo.com/v1/forecast"
params = {
	"latitude": 59.437,
	"longitude": 24.7535,
	"models": "metno_seamless",
	"current": "temperature_2m",
	#"forecast_days": 3,
	"wind_speed_unit": "ms",
}
responses = openmeteo.weather_api(url, params = params)

#Esimese asukoha info saamine. Me peaks saama ka mitu kohta vast saada korraga. Mismoodi tahame?
response = responses[0]
print(f"Koordinaadid: {response.Latitude()}°N {response.Longitude()}°E")
print(f"Kõrgus: {response.Elevation()} m asl")
#print(f"Ajatsoon GMT suhtes: {response.UtcOffsetSeconds()}s")

#Väljastame testiks info. Kas ainult temperatuuri vaja või veel miskit?:
current = response.Current()
current_temperature_2m = current.Variables(0).Value()
print(f"\nAeg: {current.Time()}")
print(f"Koht: Tallinn\ntemperatuur 2 m kõrgusel: {current_temperature_2m}")