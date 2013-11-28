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
        , 6000
      else
      # dont matter
  return @

