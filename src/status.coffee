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
        @setName data.name
        @status = Status.nowhere
      else
        Status.error "unnamed", data, "unnamed"

# Client is somewhere we do not know.
  nowhere: (data) ->
    switch data.action
      when action.client.setName
        @setName data.name
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
      when action.client.setName
        @setName data.name
        sendLobbyUpdate()

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
        @status = Status.notMyTurn
        @partner.status = Status.notMyTurn

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

  notMyTurn : (data) ->
    switch data.action
      when action.client.ready
        console.log "[TURN|GAME] #{@user.name} is ready for another turn".turn
        @ready = true
        if @partner && @partner.ready
          console.log "[TURN|GAME] Initiated another turn.".turn
          @partner.connection.send(JSON.stringify {action: action.server.turn})
          @connection.send(JSON.stringify {action: action.server.turn})
          @partner.ready = false
          @ready = false
          @partner.status = Status.myTurn
          @status = Status.myTurn

        if @partner.lost
          console.log "[INFO|GAME] #{@user.name} has found out that he won".info
          @partner.lose()

      when action.client.lose
        console.log "[INFO|GAME] #{@user.name} has announced that he lost".info
        @lost = true
        @ready = true
        if @partner.ready
          if @partner.lost
            @draw()
          else
            @lose()

      else
        Status.general.call this, "notMyTurn", data

  myTurn : (data) ->
    switch data.action
      when action.client.endTurn
        console.log "[TURN|GAME] #{@user.name} has ended his turn".turn
        if @entityCache
          console.log "[TURN|GAME] sending cached turn data to #{@user.name}".turn
          @connection.send(JSON.stringify @entityCache)
          @entityCache = null

        data.action = action.server.endTurn
        if @partner.status is Status.notMyTurn
          console.log "[TURN|GAME] sending turn data to #{@partner.user.name}".turn
          @partner.connection.send(JSON.stringify data)
        else
          console.log "[TURN|GAME] caching turn data of #{@partner.user.name}".turn
          @partner.entityCache = data

        @status = Status.notMyTurn

      when action.client.lose
        console.log "[INFO|GAME] #{@user.name} has resigned".info
        @lose()

      else
        Status.general.call this, "myTurn", data

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
        if @partner then @partner.connection.send(JSON.stringify {action: action.server.partnerLeftGameOver})
        @partner = null

      when action.client.accept
        console.log "[INFO|LOBBY] #{@partner.user.name} has accepted".info
        @partner.connection.send(JSON.stringify {action: action.server.start})
        @turn = true
        @partner.turn = false
        @status = Status.notMyTurn
        @partner.status = Status.notMyTurn

      when action.client.deny
        console.log "[INFO|LOBBY] #{@partner.user.name} has denied".info
        @partner.connection.send(JSON.stringify {action: action.server.denied})

      # something weird happened and the player is in the lobby
      when action.client.goToLobby
        @status = Status.lobby
        @status(data)

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
    console.log "[ERROR|CLIENT] #{name} has the status #{status} and can not receive the action #{data.action}".error
}
