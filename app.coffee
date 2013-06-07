# Configuration and action code JSON files
# not included in Git because hackers.
config = require "./config.json"
action = require "./action.json"

colors = require 'colors'
mongoose = require "mongoose"

colors.setTheme {
  info: 'white',
  turn: 'grey',
  warn: 'yellow',
  debug: 'magenta',
  error: 'red'
}

WebSocketServer = require('ws').Server
wss = new WebSocketServer({port: config.port})

mongoose.connect "mongodb://#{config.mongo_user}:#{config.mongo_pw}@localhost:#{config.mongo_port}/#{config.mongo_name}"

db = mongoose.connection
db.on 'error', console.error.bind(console, 'connection error:')

User = mongoose.model 'User', mongoose.Schema({
  name: String,
  phoneID: String,
  points: Number
})

clients = []
lobby = []

# Gets the names of all players in the lobby
getLobbyNames = ->
  (client.user.name for client in lobby)

# Sends the names of all players in the lobby to all players in the lobby
sendLobbyUpdate = ->
  names = getLobbyNames()
  for client in lobby
    client.connection.send(JSON.stringify {action: action.server.lobbyUpdate, names: names})

# Finds a client by his name
getClientByName = (name) ->
  for client in lobby
    if name is client.user.name then return client

# Represents a players status and handles the corresponding messages. Moar patternz be good.
Status = {

# Client does not have a name and is therefore blocked from everything except... setting a name!
  unidentified: (data) ->
    console.log data.action
    switch data.action
      when action.client.setName
        @user.name = data.value
        @status = Status.nowhere
        @connection.send(JSON.stringify {action: action.server.confirm, name: @user.name})
        console.log "A client set its name to #{@user.name}"
      else
        Status.error "unidentified", data

# Client is somewhere we do not know.
  nowhere: (data) ->
    switch data.action
      when action.client.goToLobby
        console.log "#{@user.name} goes to the lobby"
        lobby.push @
        @status = Status.lobby
        console.log "#{lobby.length} clients are in the lobby"
        sendLobbyUpdate()
      else
        Status.error "nowhere", data

# Client is in the lobby. He can now challenge other players in the lobby.
  lobby: (data) ->
    switch data.action

      when action.client.pair
        console.log "#{@user.name} wants to pair with #{data.partner.user.name}"
        @partner = getClientByName data.partner
        @partner.partner = @
        lobby.splice(lobby.indexOf @, 1)
        lobby.splice(lobby.indexOf @partner, 1)
        @partner.connection.send(JSON.stringify {action: action.server.request, partner: @user.name})

      when action.client.accept
        console.log "#{@partner.user.name} has accepted"
        @partner.connection.send(JSON.stringify {action: action.server.start})
        @status = Status.ingame
        @partner.status = Status.ingame

      when action.client.deny
        console.log "#{@partner.user.name} has denied"
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
        console.log "[TURN|GAME] #{@user.name} has made his turn".turn
        @partner.connection.send(JSON.stringify {action: action.server.turn, value: data.value})
      else
        Status.error "ingame", data

# Error logs that the status could not handle the data.
  error: (status, data) ->
    console.log "[ERROR|CLIENT] Client has the status #{status}. It can not receive the action #{data.action}".error
}

# Holds information about the client such as name and partner.
# Manages the clients connection and passes it to the status
Client = (@connection, @user) ->
  @partner = undefined
  @status = if @user.name then Status.nowhere else Status.unidentified

  @connection.on 'close', =>
    # if the player is currently playing we need to take certain steps
    if @status is Status.ingame
      @partner.connection.send(JSON.stringify {action: action.server.partnerLeft})

    console.log "[INFO|CLIENT] #{@user.name} disconnected".info
    lobby.splice(lobby.indexOf(@), 1)
    clients.splice(clients.indexOf(@), 1)
    console.log "[GLOBAL] Now there are #{clients.length} clients online.".info

  @connection.on 'message', (message) =>
    try
      data = JSON.parse message
      if data?.action then @status data
    catch e
      console.log "Error parsing #{message}: #{e}"

wss.on "connection", (ws) ->
  console.log "[INFO|GLOBAL] A client connected.".info

  # the very first message we receive needs to be the unique user id
  ws.on "message", (message) ->
    data = JSON.parse message
    User.findOne {phoneID: data.id}, (error, user) ->
      if error then console.log "[ERROR|GLOBAL] Mongo error while finding user".error
      else
        if user
          console.log "[INFO|USER] Found the user in the Database".info
          console.log "[DEBUG] Mongo find #{user.phoneID}".debug
          clients.push new Client(ws, user)
        else
          console.log "[INFO|USER] Could not find the user in the Database".info
          ws.send(JSON.stringify {action: action.server.unknownUser})
          clients.push new Client(ws, new User({phoneID: data.id}))

  console.log "[INFO|GLOBAL] Now there are #{clients.length} clients online.".info