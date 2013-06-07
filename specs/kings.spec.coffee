WebSocket = require "ws"
config = require "./config.json"
action = require "./action.json"

firstUsername = "test"
secondUsername = "test_partner"

mongoose = require "mongoose"

mongoose.connect "mongodb://#{config.mongo_user}:#{config.mongo_pw}@localhost:#{config.mongo_port}/#{config.mongo_name}"

db = mongoose.connection
db.on 'error', console.error.bind(console, 'connection error:')

User = mongoose.model 'User', mongoose.Schema({
  name: String,
  phoneID: String,
  points: Number
})

ws = undefined
ws_partner = undefined
react = ->
react_partner = ->

describe "Server", ->
  it "should allow for connection", (done) =>
    react = ->
    ws = new WebSocket "ws://localhost:#{config.port}"
    ws.on 'open', =>
      done()
    ws.on 'message', (message) =>
      react(message)

  it "should allow for a second connection", (done) =>
    react = ->
    ws_partner = new WebSocket "ws://localhost:#{config.port}"
    ws_partner.on 'open', =>
      done()
    ws_partner.on 'message', (message) =>
      react_partner(message)

describe "User Services", ->
  it "should not find the first user on first login", (done) =>
    react = (message) ->
      data = JSON.parse message
      if data.action is action.server.unknownUser then done()
    ws.send(JSON.stringify {action: action.client.setID, id: "test"})

  it "should not find the second user on first login", (done) =>
    react_partner = (message) ->
      data = JSON.parse message
      if data.action is action.server.unknownUser then done()
    ws_partner.send(JSON.stringify {action: action.client.setID, id: "test2"})

  it "should allow the first user to set a name", (done) =>
    react = (message) ->
      data = JSON.parse message
      if data.action is action.server.confirm and data.name is firstUsername then done()
    ws.send(JSON.stringify {action: action.client.setName, value: firstUsername})

  it "should allow the second user to set a name", (done) =>
    react_partner = (message) ->
      data = JSON.parse message
      if data.action is action.server.confirm and data.name is secondUsername then done()
    ws_partner.send(JSON.stringify {action: action.client.setName, value: secondUsername})

  it "should save the user name", (done) =>
    User.findOne {phoneID: "test"}, (err, user) ->
      if err then throw err else if user.name is firstUsername then done()

describe "Lobby Services", ->
  it "should allow the first user to go to the lobby", (done) =>
    react = (message) ->
      data = JSON.parse message
      if data.action is action.server.lobbyUpdate and firstUsername in data.names then done()
    ws.send(JSON.stringify {action: action.client.goToLobby})

  it "should allow the second user to go to the lobby", (done) =>
    react_partner = (message) ->
      data = JSON.parse message
      if data.action is action.server.lobbyUpdate and firstUsername in data.names and secondUsername in data.names then done()
    ws_partner.send(JSON.stringify {action: action.client.goToLobby})

  it "should allow the first user to challenge the second, who denies", (done) =>
    react_partner = (message) ->
      data = JSON.parse message
      if data.action is action.server.request and data.partner is firstUsername
        ws_partner.send(JSON.stringify {action: action.client.deny})
    react = (message) ->
      data = JSON.parse message
      if data.action is action.server.denied then done()
    ws.send(JSON.stringify {action: action.client.pair, partner: secondUsername})

  it "should allow the first user to challenge the second, who accepts", (done) =>
    react_partner = (message) ->
      data = JSON.parse message
      if data.action is action.server.request and data.partner is firstUsername
        ws_partner.send(JSON.stringify {action: action.client.accept})
    react = (message) ->
      data = JSON.parse message
      if data.action is action.server.start then done()
    ws.send(JSON.stringify {action: action.client.pair, partner: secondUsername})

describe "Game Services", ->

  it "should not allow the first user to have the first turn", ->
    react_partner = () ->
      throw "err"
    ws.send(JSON.stringify {action: action.client.turn, value: 999})

  it "should allow the second user to have the first turn", ->
    react_partner = ->
    react = (message) ->
      data = JSON.parse message
      if data.action is action.server.turn and data.value is 999 then done()
    ws_partner.send(JSON.stringify {action: action.client.turn, value: 999})

  it "should allow the first user to have the second turn", ->
    react = ->
    react_partner = (message) ->
      data = JSON.parse message
      if data.action is action.server.turn and data.value is 888 then done()
    ws.send(JSON.stringify {action: action.client.turn, value: 888})

  it "should allow the second user to have the third turn", ->
    react_partner = ->
    react = (message) ->
      data = JSON.parse message
      if data.action is action.server.turn and data.value is 777 then done()
    ws_partner.send(JSON.stringify {action: action.client.turn, value: 777})

  it "should allow the first user to announce that he lost", ->
    react = ->
    react_partner = (message) ->
      data = JSON.parse message
      if data.action is action.server.youWin then done()
    ws.send(JSON.stringify {action: action.client.lose})

describe "Server", ->
  it "should successfully close the connections", =>
    ws.close()
    ws_partner.close()
    cleanUp()

cleanUp = ->
  User.findOne {phoneID: "test"}, (err, user) ->
    if err then throw err else user?.remove()
  User.findOne {phoneID: "test2"}, (err, user) ->
    if err then throw err else user?.remove()