
import json
import urllib.request
import psycopg

URL = "https://dashboard.elering.ee/api/nps/price"
conn = psycopg.connect(
	host="localhost",
	dbname="aaaa",
	user="usr",
	password="psw111111"
)

with conn:
	with conn.cursor() as cur:
		with urllib.request.urlopen(URL) as response:
			data = json.load(response)
		read = data.get("data", {}).get("ee", [])
		for rida in read:
			try:
				timestamp = rida["timestamp"]
				price = rida["price"]
				if not isinstance(timestamp, int):
					raise ValueError("Paanika, sisendis 'timestamp' vigane")
				if not isinstance(price, float):
					raise ValueError("price ei ole arv")

				price_int = int(round(price * 10000))
				cur.execute("INSERT INTO elektrihind (aeg, hind) VALUES (%s, %s) ON CONFLICT (aeg) DO NOTHING", (timestamp, price_int))

			except Exception as e:
				print(
					f"Viga: {e}; "
					f"aeg={rida.get('timestamp')}; "
					f"hind={rida.get('price')}; "
					f"rida={rida}"
				)