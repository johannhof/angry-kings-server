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
  won: Number,
  lost: Number
})

clients = []
lobby = []

removeClient = (toRemove, array) ->
  i = 0
  for client in array
    if client.user?.phoneID is toRemove.user.phoneID
      return array.splice(i, 1)
    i++

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

# Represents a players status and handles the corresponding messages. Moar patternz be good.
Status = {

# the very first message we receive needs to be the unique user id
  unidentified: (data) ->
    if data.action is action.client.setID
      User.findOne {phoneID: data.id}, (error, user) =>
        if error then console.log "[ERROR|GLOBAL] Mongo error while finding user".error
        else
          if user
            console.log "[INFO|USER] Found the user #{user.name} in the Database".info
            @user = user
            @status = Status.nowhere
            @connection.send(JSON.stringify {action: action.server.knownUser, name: @user.name})
          else
            console.log "[INFO|USER] Could not find the user in the Database".info
            @connection.send(JSON.stringify {action: action.server.unknownUser})
            @user = new User({phoneID: data.id})
            @status = Status.unnamed
    else Status.error "unidentified", data, "unknown"

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
        Status.error "unnamed", data, "unnamed"

# Client is somewhere we do not know.
  nowhere: (data) ->
    switch data.action
      when action.client.goToLobby
        console.log "[INFO|CLIENT] #{@user.name} goes to the lobby".info
        lobby.push @
        @status = Status.lobby
        sendLobbyUpdate()
      else
        Status.general.call this, "nowhere", data

# Client is in the lobby. He can now challenge other players in the lobby.
  lobby: (data) ->
    switch data.action

      when action.client.pair
        console.log "[INFO|LOBBY] #{@user.name} wants to pair with #{data.partner}".info
        if data.partner is "ray"
          @partner = new Dummy()
        else
          @partner = getClientByID data.partner

        if @partner and not @partner.partner and @partner.status is Status.lobby
          @partner.partner = @
          @partner.connection.send(JSON.stringify {action: action.server.request, partner: @user.name})
        else
          @connection.send(JSON.stringify {action: action.server.denied})
          @partner = null

      when action.client.accept
        console.log "[INFO|LOBBY] #{@partner.user.name} has accepted".info
        removeClient @, lobby
        removeClient @partner, lobby
        sendLobbyUpdate()
        @partner.connection.send(JSON.stringify {action: action.server.start})
        @turn = true
        @partner.turn = false
        @status = Status.ingame
        @partner.status = Status.ingame

      when action.client.deny
        console.log "[INFO|LOBBY] #{@partner.user.name} has denied".info
        @partner.connection.send(JSON.stringify {action: action.server.denied})
        @partner.partner = undefined
        @partner = undefined
        sendLobbyUpdate()

      when action.client.leaveLobby
        console.log "[INFO|LOBBY] #{@user.name} leaves the lobby".info
        removeClient @, lobby
        @status = Status.nowhere
        sendLobbyUpdate()

    # if someone restarted his lobby
      when action.client.goToLobby
        sendLobbyUpdate()
      else
        Status.general.call this, "lobby", data

# Client is currently in a running game.
  ingame: (data) ->
    switch data.action
      when action.client.turn
        if @turn
          console.log "[TURN|GAME] #{@user.name} has made his turn".turn
          @partner.connection.send(JSON.stringify {action: action.server.turn, x: data.x, y: data.y})
        else
          console.log "[WARNING|GAME] Client #{@user.name} tried to have a turn although his partner is it".warn

      when action.client.endTurn
        if @turn
          @turn = false
          @partner.turn = true
          console.log "[TURN|GAME] #{@user.name} has ended his turn".turn
          @partner.connection.send(JSON.stringify {action: action.server.endTurn, entities: data.entities})
        else
          console.log "[WARNING|GAME] Client #{@user.name} tried to end a turn although his partner is it".warn

      when action.client.lose
        console.log "[INFO|GAME] #{@user.name} has announced that he lost".info
        console.log "[INFO|GAME] #{@partner.user.name} has won the game against #{@user.name}".info
        @partner.connection.send(JSON.stringify {action: action.server.youWin})

        if @partner.user.won
          @partner.user.won++
        else
          @partner.user.won = 1

        if @user.lost
          @user.lost++
        else
          @user.lost = 1

        @user.save()
        @partner.user.save()
        @partner.status = Status.gameOver
        @status = Status.gameOver
      else
        Status.general.call this, "ingame", data

  gameOver: (data) ->
    switch data.action
      when action.client.revenge
        if @partner and @partner.status is Status.gameOver
          console.log "[INFO|GAMEOVER] #{@user.name} wants play again with #{@partner.user.name}".info
          @partner.connection.send(JSON.stringify {action: action.server.request, partner: @user.name})
        else
          @connection.send(JSON.stringify {action: action.server.denied})
          @partner = null

      when action.client.leaveGameOver
        console.log "[INFO|GAMEOVER] #{@user.name} leaves the game over area".info
        @status = Status.nowhere
        @partner = null

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

      else
        Status.general.call this, "gameOver", data

  general: (source, data) ->
    switch data.action
      when action.client.getName
        console.log "[INFO|CLIENT] Client #{@user.name} asked for his name".info
        @connection.send(JSON.stringify {action: action.server.sendName, name: @user.name})
      else
        Status.error source, data, @user.name

# Error logs that the status could not handle the data.
  error: (status, data, name) ->
    console.log "[ERROR|CLIENT] Client #{name} has the status #{status}. It can not receive the action #{data.action}".error
}

Dummy = ->
  @partner = undefined
  @status = Status.lobby
  @user = {
    name: "Ray the Dummy"
    _id: "ray"
    phoneID: "asdasdasd" + Math.random() * 1000
    won: 999
    lost: 0
    save: ->
  }

  @connection = {}
  x = 0
  y = 0

  @connection.send = (json) =>
    data = JSON.parse json
    switch data.action
      when action.server.request
        @status {action: action.client.accept}
        setTimeout =>
          @status {action: action.client.turn, x: 100, y: -100}
        , 5000
        setTimeout =>
          @status {action: action.client.endTurn, entities: []}
        , 17000
      when action.server.turn
        x = - data.x
        y = data.y
      when action.server.endTurn
        @status {action: action.client.turn, x: x, y: y}
        setTimeout =>
          @status {action: action.client.endTurn, entities: []}
        , 12000
      else
      # dont matter
  return @

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
    removeClient @, lobby
    removeClient @, clients
    sendLobbyUpdate()
    console.log "[INFO|GLOBAL] Now there are #{clients.length} clients online.".info

  @connection.on 'message', (message) =>
    try
      data = JSON.parse message
    catch e
      console.log "[ERROR|CLIENT] Error parsing message #{message}: #{e}".error
    if data?.action then @status data

  return @

# starting point for each connection
wss.on "connection", (ws) ->
  console.log "[INFO|GLOBAL] A client connected.".info
  clients.push new Client(ws)
  console.log "[INFO|GLOBAL] Now there are #{clients.length} clients online.".info

# DUMMY PARTNER FOR TESTING
lobby.push new Dummy()

# catches all other exceptions and prevents the server from crashing
process.on 'uncaughtException', (err) ->
  console.error err
  console.log "Error caught by Batman. Node not exiting."
