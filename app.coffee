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

# the very first message we receive needs to be the unique user id
  unidentified: (data) ->
    if data.action is action.client.setID
      User.findOne {phoneID: data.id}, (error, user) =>
        if error then console.log "[ERROR|GLOBAL] Mongo error while finding user".error
        else
          if user
            console.log "[INFO|USER] Found the user in the Database".info
            @user = user
            @status = Status.nowhere
            @connection.send(JSON.stringify {action: action.server.knownUser, name: @user.name})
          else
            console.log "[INFO|USER] Could not find the user in the Database".info
            @connection.send(JSON.stringify {action: action.server.unknownUser})
            @user = new User({phoneID: data.id})
            @status = Status.unnamed
    else Status.error "unidentified", data

# Client does not have a name and is therefore blocked from everything except... setting a name!
  unnamed: (data) ->
    switch data.action
      when action.client.setName
        @user.name = data.name
        @status = Status.nowhere
        @connection.send(JSON.stringify {action: action.server.confirm, name: @user.name})
        console.log "[INFO|CLIENT] A client set its name to #{@user.name}".info
        @user.save()
      else
        Status.error "unnamed", data

# Client is somewhere we do not know.
  nowhere: (data) ->
    switch data.action
      when action.client.goToLobby
        console.log "[INFO|CLIENT] #{@user.name} goes to the lobby".info
        lobby.push @
        @status = Status.lobby
        console.log "[INFO|LOBBY] #{lobby.length} clients are in the lobby".info
        sendLobbyUpdate()
      else
        Status.error "nowhere", data

# Client is in the lobby. He can now challenge other players in the lobby.
  lobby: (data) ->
    switch data.action

      when action.client.pair
        console.log "[INFO|LOBBY] #{@user.name} wants to pair with #{data.partner}".info
        @partner = getClientByName data.partner
        @partner.partner = @
        lobby.splice(lobby.indexOf @, 1)
        lobby.splice(lobby.indexOf @partner, 1)
        @partner.connection.send(JSON.stringify {action: action.server.request, partner: @user.name})

      when action.client.accept
        console.log "[INFO|LOBBY] #{@partner.user.name} has accepted".info
        @partner.connection.send(JSON.stringify {action: action.server.start})
        @turn = true
        @partner.turn = false
        @status = Status.ingame
        @partner.status = Status.ingame

      when action.client.deny
        console.log "[INFO|LOBBY] #{@partner.user.name} has denied".info
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
        if @turn
          @turn = false
          @partner.turn = true
          console.log "[TURN|GAME] #{@user.name} has made his turn".turn
          @partner.connection.send(JSON.stringify {action: action.server.turn, value: data.value})
        else
          console.log "[WARNING|GAME] Client #{@user.name} tried to have a turn although his partner is it".warn
      when action.client.lose
        console.log "[INFO|GAME] #{@user.name} has announced that he lost".info
        console.log "[INFO|GAME] #{@partner.user.name} has won the game against #{@user.name}".info
        @partner.connection.send(JSON.stringify {action: action.server.youWin})
        @partner.status = Status.nowhere
        @status = Status.nowhere
        @partner.partner = undefined
        @partner = undefined
      else
        Status.error "ingame", data

# Error logs that the status could not handle the data.
  error: (status, data) ->
    console.log "[ERROR|CLIENT] Client has the status #{status}. It can not receive the action #{data.action}".error
}

# Holds information about the client such as name and partner.
# Manages the clients connection and passes it to the status
Client = (@connection) ->
  @partner = undefined
  @user = undefined
  @status = Status.unidentified
  @turn = false

  @connection.on 'close', =>
    # if the player is currently playing we need to take certain steps
    if @status is Status.ingame
      console.log "[WARNING|CLIENT] Client #{@user.name} left a running game. Notifying partner...".warn
      # we need try catch here because the partner might have left already by now
      try
        @partner.status = Status.nowhere
        @partner.partner = undefined
        @partner.connection.send(JSON.stringify {action: action.server.partnerLeft})
      catch e

    console.log "[INFO|CLIENT] #{@user?.name} disconnected".info
    lobby.splice(lobby.indexOf(@), 1)
    clients.splice(clients.indexOf(@), 1)
    console.log "[INFO|GLOBAL] Now there are #{clients.length} clients online.".info

  @connection.on 'message', (message) =>
    try
      data = JSON.parse message
    catch e
      console.log "[ERROR|CLIENT] Error parsing message #{message}: #{e}".error
    if data?.action then @status data

wss.on "connection", (ws) ->
  console.log "[INFO|GLOBAL] A client connected.".info
  clients.push new Client(ws)
  console.log "[INFO|GLOBAL] Now there are #{clients.length} clients online.".info