import requests
import json

URL = "http://127.0.0.1:5000/api/upload"

with open("../../../interet_web_site/static/data/data.json", "r") as f:
    data = json.load(f)

response = requests.post(URL, json=data)

print("Status:", response.status_code)
print("Response:", response.json())