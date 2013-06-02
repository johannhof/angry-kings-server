# Configuration and action code JSON files
# not included in Git because hackers.
config = require "./config.json"
action = require "./action.json"

WebSocketServer = require('ws').Server
wss = new WebSocketServer({port: config.port})

clients = []
lobby = []

# Gets the names of all players in the lobby
getLobbyNames = ->
  (client.name for client in lobby)

# Sends the names of all players in the lobby to all players in the lobby
sendLobbyUpdate = ->
  names = getLobbyNames()
  for client in lobby
    client.connection.send(JSON.stringify {action: action.server.lobbyUpdate, names: names})

# Finds a client by his name
getClientByName = (name) ->
  for client in lobby
    if name is client.name then return client

# Represents a players status and handles the corresponding messages. Moar patternz be good.
Status = {

  # Client does not have a name and is therefore blocked from everything except... setting a name!
  unidentified: (data) ->
    console.log data.action
    switch data.action
      when action.client.setName
        @name = data.value
        @status = Status.nowhere
        @connection.send(JSON.stringify {action: "confirm", name : @name})
        console.log "A client set its name to #{@name}"
      else
        Status.error "unidentified", data

  # Client is somewhere we do not know.
  nowhere: (data) ->
    switch data.action
      when action.client.goToLobby
        console.log "#{@name} goes to the lobby"
        lobby.push @
        console.log "#{lobby.length} clients are in the lobby"
        sendLobbyUpdate()
      else
        Status.error "nowhere", data

  # Client is in the lobby. He can now challenge other players in the lobby.
  lobby: (data) ->
    switch data.action

      when action.client.pair
        console.log "#{@name} wants to pair with #{data.partner}"
        @partner = getClientByName data.partner
        @partner.partner = @
        lobby.splice(lobby.indexOf @, 1)
        lobby.splice(lobby.indexOf @partner, 1)
        @partner.connection.send(JSON.stringify {action: action.server.request, partner: @name})

      when action.client.accept
        console.log "#{@partner.name} has accepted"
        @partner.connection.send(JSON.stringify {action: action.server.start})

      when action.client.deny
        console.log "#{@partner.name} has denied"
        @partner.connection.send(JSON.stringify {action: action.server.denied})
        lobby.push @
        lobby.push @partner
        @partner.partner = undefined
        @partner = undefined
        sendLobbyUpdate()
      else
        Status.error "lobby", data

  # Client is currently in a running game.
  ingame: (data) ->
    switch data.action
      when action.client.turn
        console.log "#{@name} has made his turn"
        @partner.connection.send(JSON.stringify {action : action.server.turn} )
      else
        Status.error "ingame", data

  # Error logs that the status could not handle the data.
  error: (status, data) ->
    console.log "Client has the status #{status}. It can not receive the action #{data.action}"
}

# Holds information about the client such as name and partner.
# Manages the clients connection and passes it to the status
Client = (@connection) ->
  @partner = undefined
  @name = undefined
  @status = Status.unidentified
  @connection.on 'close', =>
    console.log "#{@name} disconnected"
    lobby.splice(lobby.indexOf(@), 1)
    clients.splice(clients.indexOf(@), 1)
    console.log "Now there are #{clients.length} clients online."
  @connection.on 'message', (message) =>
    try
      data = JSON.parse message
      if data?.action then @status data
    catch e
      console.log "Error parsing #{message}: #{e}"

wss.on "connection", (ws) ->
  console.log "A client connected."
  clients.push new Client(ws)
  console.log "Now there are #{clients.length} clients online."