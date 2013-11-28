
lobby = []

# Gets the names, lost and won games of all players in the lobby
getLobbyNames = (excludeID) ->
  ([client.user.name,
    client.user._id,
    client.user.won || 0,
    client.user.lost || 0] for client in lobby when client.user.phoneID isnt excludeID)

# Sends the names of all players in the lobby to all players in the lobby
sendLobbyUpdate = ->
  console.log "[INFO|LOBBY] #{lobby.length} clients are in the lobby: #{getLobbyNames(null)}".info
  for client in lobby
    names = getLobbyNames(client.user.phoneID)
    client.connection.send(JSON.stringify {action: action.server.lobbyUpdate, names: names})

# Finds a client by his name
getClientByName = (name) ->
  for client in lobby
    if name is client.user.name then return client

# Finds a client by his name
getClientByID = (id) ->
  for client in lobby
    # cast id to string
    if id is client.user._id + "" then return client

