WebSocket = require "ws"
config = require "../config.json"
action = require "../action.json"

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

  beforeEach ->
    react_partner = ->

    react = ->

  it "should allow for connection", (done) =>
    ws = new WebSocket "ws://localhost:#{config.port}"
    ws.on 'open', =>
      done()
    ws.on 'message', (message) =>
      react(message)

  it "should allow for a second connection", (done) =>
    ws_partner = new WebSocket "ws://localhost:#{config.port}"
    ws_partner.on 'open', =>
      done()
    ws_partner.on 'message', (message) =>
      react_partner(message)

describe "User Services", ->
  it "should not find the first user on first login", (done) =>
    react = (message) ->
      data = JSON.parse message
      expect(data.action).toBe(action.server.unknownUser)
      done()
    ws.send(JSON.stringify {action: action.client.setID, id: "test"})

  it "should not find the second user on first login", (done) =>
    react_partner = (message) ->
      data = JSON.parse message
      expect(data.action).toBe(action.server.unknownUser)
      done()
    ws_partner.send(JSON.stringify {action: action.client.setID, id: "test2"})

  it "should allow the first user to set a name", (done) =>
    react = (message) ->
      data = JSON.parse message
      expect(data.action).toBe(action.server.confirm)
      expect(data.name).toBe(firstUsername)
      done()
    ws.send(JSON.stringify {action: action.client.setName, name: firstUsername})

  it "should allow the second user to set a name", (done) =>
    react_partner = (message) ->
      data = JSON.parse message
      if data.action is action.server.confirm and data.name is secondUsername then done()
    ws_partner.send(JSON.stringify {action: action.client.setName, name: secondUsername})

  it "should save the user name", (done) =>
    User.findOne {phoneID: "test"}, (err, user) ->
      if err then throw err else if user.name is firstUsername then done()

  it "should allow the first user to get his name", (done) =>
    react = (message) ->
      data = JSON.parse message
      expect(data.action).toBe(action.server.sendName)
      expect(data.name).toBe(firstUsername)
      done()
    ws.send(JSON.stringify {action: action.client.getName})

describe "Lobby Services", ->

  beforeEach ->
    react_partner = ->

    react = ->

  it "should allow the first user to go to the lobby", (done) =>
    react = (message) ->
      data = JSON.parse message
      if data.action is action.server.lobbyUpdate and firstUsername not in data.names then done()
    ws.send(JSON.stringify {action: action.client.goToLobby})

  it "should allow the second user to go to the lobby and get data from other players", (done) =>
    react_partner = (message) ->
      data = JSON.parse message
      names = (name[0] for name in data.names)
      won = (name[1] for name in data.names)
      lost = (name[2] for name in data.names)
      if data.action is action.server.lobbyUpdate and firstUsername in names and lost[0] is 0 and secondUsername not in names then done()
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

  beforeEach ->
    react_partner = ->
    react = ->

  it "should not allow the first user to have the first turn", ->
    react_partner = () ->
      throw "err"
    ws.send(JSON.stringify {action: action.client.turn, x: 999, y: 999})

  it "should allow the second user to have the first turn", (done) ->
    react = (message) ->
      data = JSON.parse message
      if data.action is action.server.turn and data.x is 999 and data.y is 999 then done()
    ws_partner.send(JSON.stringify {action: action.client.turn, x: 999, y: 999})

  it "should allow the second user to end the first turn", (done) ->
    array = [{id: 42, x: 999.0, y: 999.0, rotation: 23.23},{id: 23, x: 929.0, y: 933.0, rotation: 23.23}]
    react = (message) ->
      data = JSON.parse message
      expect(data.action).toBe(action.server.endTurn)
      expect(data.entities).toEqual(array)
      done()
    ws_partner.send(JSON.stringify {action: action.client.endTurn, entities: array})

  it "should allow the first user to have the second turn",(done) ->
    react_partner = (message) ->
      data = JSON.parse message
      if data.action is action.server.turn and data.x is 888 then done()
    ws.send(JSON.stringify {action: action.client.turn, x: 888, y: 888})

  it "should allow the first user to end the second turn", (done) ->
    array = [{id: 42, x: 999.0, y: 999.0, rotation: 23.23},{id: 23, x: 929.0, y: 933.0, rotation: 23.23}]
    react_partner = (message) ->
      data = JSON.parse message
      expect(data.action).toBe(action.server.endTurn)
      expect(data.entities).toEqual(array)
      done()
    ws.send(JSON.stringify {action: action.client.endTurn, entities: array})

  it "should allow the second user to have the third turn", (done) ->
    react = (message) ->
      data = JSON.parse message
      if data.action is action.server.turn and data.x is 777 then done()
    ws_partner.send(JSON.stringify {action: action.client.turn, x: 777, y: 777})

  it "should allow the first user to announce that he lost", (done) ->
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