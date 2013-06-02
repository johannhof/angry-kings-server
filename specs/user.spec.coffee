WebSocket = require "ws"
config = require "./config.json"
action = require "./action.json"

describe "User Services", ->
  it "should allow for connection", (done) =>
    @react = ->
    @ws = new WebSocket "ws://localhost:#{config.port}"
    @ws.on 'open', =>
      done()
    @ws.on 'message', (message) =>
      @react(message)

  it "should allow the user to set a name", (done) =>
    @react = (message) ->
      data = JSON.parse message
      if data.action is "confirm" and data.name is "test" then done()
    @ws.send(JSON.stringify {action: action.client.setName, value: "test"})

  it "should successfully close the connection", =>
    @ws.close()