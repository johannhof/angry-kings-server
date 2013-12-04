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

  @lose = -> Client.lose.call this
  @draw = -> Client.lose.draw this

  @connection = {}
  x = 0
  y = 0

  @connection.send = (json) =>
    data = JSON.parse json
    switch data.action
      when action.server.request
        @status {action: action.client.accept}
        @status {action: action.client.ready}

      when action.server.turn
        setTimeout =>
          @status {action: action.client.endTurn, entities: [], x: 100, y: -100}
        , 2000

      when action.server.endTurn
        x = - data.x
        y = data.y
        setTimeout =>
          @status {action: action.client.ready}
        , 2000

      else
      # dont matter

  return @

