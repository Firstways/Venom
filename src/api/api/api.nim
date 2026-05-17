import std/[httpclient, json]


proc send_data*(payload:JsonNode)=
  var client = newHttpClient()

  client.headers = newHttpHeaders({
    "Content-Type": "application/json"
  })

  try:
    # Requête HTTPS POST
    let response = client.request(
      url = "http://localhost:5000/api/upload",
      httpMethod = HttpPost,
      body = $payload
    )

    echo "Code HTTP : ", response.code
    echo "Réponse :"
    echo response.body
   
  except CatchableError as e:
    echo "Erreur : ", e.msg
  finally:
     client.close()

