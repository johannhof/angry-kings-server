WebSocket = require "ws"
config = require "./config.json"

describe "User Services", ->
  it "should allow for connection", (done) =>
    @ws = new WebSocket "ws://localhost:#{config.port}"
    @ws.on 'open', =>
      done()

  it "should allow the user to set a name", (done) =>
    @ws.send()

  it "should successfully close the connection", =>
    @ws.close()