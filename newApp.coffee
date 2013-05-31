WebSocketServer = require('ws').Server
wss = new WebSocketServer({port: 61224})
lobby = []
clients = []

getLobbyNames = ->
  (client.name for client in lobby)

sendLobbyUpdate = ->
  names = getLobbyNames()
  for client in lobby
    client.connection.send(JSON.stringify({action: "lobbyUpdate", names: names}))

getClientByName = (name) ->
  for client in lobby
    if name is client.name then return client

Status = {
  unidentified: (data) ->
    switch data.action
      when "name"
        @name = data.value
        console.log "A client set its name to #{@name}"
      else
        Status.unrecognized "unidentified", data
  nowhere: (data) ->
    switch data.action
      when "lobby"
        console.log "#{@name} goes to the lobby"
        lobby.push(@)
        sendLobbyUpdate()
      else
        Status.unrecognized "nowhere", data
  lobby: (data) ->
    switch data.action
      when "pair"
        console.log "#{@name} wants to pair with #{data.partner}"
        @partner = getClientByName data.partner
        @partner.partner = @;
        lobby.splice(lobby.indexOf @, 1)
        lobby.splice(lobby.indexOf @partner, 1)
        @partner.connection.send(JSON.stringify {action: "request", partner: @name})
      when "accept"
        console.log "#{@partner.name} has accepted"
        @partner.connection.send(JSON.stringify {action: "start"})
      when "deny"
        console.log "#{@partner.name} has denied"
        @partner.connection.send(JSON.stringify {action: "denied"})
        lobby.push @;
        lobby.push @partner;
        @partner.partner = undefined;
        @partner = undefined;
        sendLobbyUpdate();
      else
        Status.unrecognized "lobby", data
  ingame: (data) ->
    switch data.action
      when "lobby"
        console.log "#{@name} goes to the lobby"
        lobby.push(@)
        sendLobbyUpdate()
      else
        Status.unrecognized "nowhere", data
  unrecognized: (status, data) ->
    console.log "Client has the status #{status}. It can not receive the action #{data.action}"
}

Client = (@connection) ->
  @partner = undefined
  @name = undefined
  @status = Status.unidentified
  @connection.on 'close', =>
    console.log "#{@name} disconnected"
    lobby.splice(lobby.indexOf(self), 1)
    console.log "Now there are #{clients.length} clients online."
  @connection.on 'message', (message) =>
    try
      data = JSON.parse(message)
      if data?.action then @status data
    catch e
      console.log "Error parsing #{message}: #{e}"