
clients = []

removeClient = (toRemove, array) ->
  i = 0
  for client in array
    if client.user?.phoneID is toRemove.user.phoneID
      return array.splice(i, 1)
    i++

# Holds information about the client such as name and partner.
# Manages the clients connection and passes it to the status
Client = (@connection) ->
  @partner = undefined
  @user = undefined
  @status = Status.unidentified
  @turn = false

  @setName = (name) ->
    console.log "[INFO|CLIENT] #{@user.name} set his name to #{name}".info
    @user.name = name
    @connection.send(JSON.stringify {action: action.server.confirm, name: @user.name})
    @user.save()

  @draw = ->
    console.log "[INFO|GAME] #{@partner.user.name} and #{@user.name} have drawn.".info
    @partner.connection.send(JSON.stringify {action: action.server.draw})
    @connection.send(JSON.stringify {action: action.server.draw})

    @lost = false
    @partner.lost = false

    @ready = false
    @partner.ready = false

    @partner.status = Status.gameOver
    @status = Status.gameOver

  @lose = ->
    @lost = false
    @ready = false
    @partner.ready = false
    console.log "[INFO|GAME] #{@partner.user.name} has won the game against #{@user.name}".info
    @partner.connection.send(JSON.stringify {action: action.server.youWin})
    @connection.send(JSON.stringify {action: action.server.youLose})

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

