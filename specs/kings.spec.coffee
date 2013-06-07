WebSocket = require "ws"
config = require "./config.json"
action = require "./action.json"

ws = undefined
ws_partner = undefined
react = ->

describe "Server", ->
  it "should allow for connection", (done) =>
    react = ->
    ws = new WebSocket "ws://localhost:#{config.port}"
    ws.on 'open', =>
      done()
    ws.on 'message', (message) =>
      react(message)

###
it "should allow for a second connection", (done) =>
react = ->
ws_partner = new WebSocket "ws://localhost:#{config.port}"
ws_partner.on 'open', =>
done()
ws_partner.on 'message', (message) =>
react(message)
###

describe "User Services", ->
  it "should not find the user on first login", (done) =>
    react = (message) ->
      data = JSON.parse message
      if data.action is action.server.unknownUser then done()
    ws.send(JSON.stringify {id: "test"})

  it "should allow the user to set a name", (done) =>
    react = (message) ->
      data = JSON.parse message
      if data.action is action.server.confirm and data.name is "test" then done()
    ws.send(JSON.stringify {action: action.client.setName, value: "test"})

describe "Lobby Services", ->
  it "should allow the user to go to the lobby", (done) =>
    react = (message) ->
      data = JSON.parse message
      if data.action is action.server.lobbyUpdate and "test" in data.names then done()
    ws.send(JSON.stringify {action: action.client.goToLobby})

describe "Game Services", ->

describe "Server", ->
  it "should successfully close the connection", =>
    ws.close()
