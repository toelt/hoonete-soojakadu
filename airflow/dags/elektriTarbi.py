
import json
import urllib.request
import psycopg

URL = "https://dashboard.elering.ee/api/system/with-plan"
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
		read = data.get("data", {}).get("real", [])
		for rida in read:
			try:
				aeg = rida["timestamp"]
				tootmine = rida["production"]
				tarbimine = rida["consumption"]

				if not isinstance(aeg, int):
					raise ValueError("Paanika, sisendis 'timestamp' vigane")
				if not isinstance(tootmine, float):
					raise ValueError("production ei ole arv")
				if not isinstance(tarbimine, float):
					raise ValueError("consumption ei ole arv")

				tootmineInt = int(round(tootmine * 10000))
				tarbimineInt = int(round(tarbimine * 10000))
				cur.execute("INSERT INTO elektritarbi (aeg, tootmine, tarbimine) VALUES (%s, %s, %s) ON CONFLICT (aeg) DO NOTHING", (aeg, tootmineInt, tarbimineInt))

			except Exception as e:
				print(
					f"Viga: {e}; "
					f"aeg={rida.get('timestamp')}; "
					f"tootmine={rida.get('production')}; "
					f"tarbimine={rida.get('consumption')}; "
					f"rida={rida}"
				)