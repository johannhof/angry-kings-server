var Client, Dummy, Status, User, WebSocketServer, action, clients, colors, config, db, getClientByID, getClientByName, getLobbyNames, lobby, mongoose, removeClient, sendLobbyUpdate, wss;

config = require("./config.json");

action = require("./action.json");

colors = require('colors');

mongoose = require("mongoose");

colors.setTheme({
  info: 'white',
  turn: 'grey',
  warn: 'yellow',
  debug: 'magenta',
  error: 'red',
  server: 'green'
});

clients = [];

removeClient = function(toRemove, array) {
  var client, i, _i, _len, _ref;
  i = 0;
  for (_i = 0, _len = array.length; _i < _len; _i++) {
    client = array[_i];
    if (((_ref = client.user) != null ? _ref.phoneID : void 0) === toRemove.user.phoneID) {
      return array.splice(i, 1);
    }
    i++;
  }
};

Client = function(connection) {
  var _this = this;
  this.connection = connection;
  this.partner = void 0;
  this.user = void 0;
  this.status = Status.unidentified;
  this.turn = false;
  this.setName = function(name) {
    console.log(("[INFO|CLIENT] " + this.user.name + " set his name to " + name).info);
    this.user.name = name;
    this.connection.send(JSON.stringify({
      action: action.server.confirm,
      name: this.user.name
    }));
    return this.user.save();
  };
  this.draw = function() {
    console.log(("[INFO|GAME] " + this.partner.user.name + " and " + this.user.name + " have drawn.").info);
    this.partner.connection.send(JSON.stringify({
      action: action.server.draw
    }));
    this.connection.send(JSON.stringify({
      action: action.server.draw
    }));
    this.lost = false;
    this.partner.lost = false;
    this.ready = false;
    this.partner.ready = false;
    this.partner.status = Status.gameOver;
    return this.status = Status.gameOver;
  };
  this.lose = function() {
    this.lost = false;
    this.ready = false;
    this.partner.ready = false;
    console.log(("[INFO|GAME] " + this.partner.user.name + " has won the game against " + this.user.name).info);
    this.partner.connection.send(JSON.stringify({
      action: action.server.youWin
    }));
    this.connection.send(JSON.stringify({
      action: action.server.youLose
    }));
    if (this.partner.user.won) {
      this.partner.user.won++;
    } else {
      this.partner.user.won = 1;
    }
    if (this.user.lost) {
      this.user.lost++;
    } else {
      this.user.lost = 1;
    }
    this.user.save();
    this.partner.user.save();
    this.partner.status = Status.gameOver;
    return this.status = Status.gameOver;
  };
  this.connection.on('close', function() {
    var e, _ref;
    if (_this.status === Status.ingame) {
      console.log(("[WARNING|CLIENT] Client " + _this.user.name + " left a running game. Notifying partner...").warn);
      try {
        _this.partner.status = Status.nowhere;
        _this.partner.partner = void 0;
        _this.partner.connection.send(JSON.stringify({
          action: action.server.partnerLeft
        }));
      } catch (_error) {
        e = _error;
      }
    }
    console.log(("[INFO|CLIENT] " + ((_ref = _this.user) != null ? _ref.name : void 0) + " disconnected").info);
    removeClient(_this, lobby);
    removeClient(_this, clients);
    sendLobbyUpdate();
    return console.log(("[INFO|GLOBAL] Now there are " + clients.length + " clients online.").info);
  });
  this.connection.on('message', function(message) {
    var data, e;
    try {
      data = JSON.parse(message);
    } catch (_error) {
      e = _error;
      console.log(("[ERROR|CLIENT] Error parsing message " + message + ": " + e).error);
    }
    if (data != null ? data.action : void 0) {
      return _this.status(data);
    }
  });
  return this;
};

Dummy = function() {
  var x, y,
    _this = this;
  this.partner = void 0;
  this.status = Status.lobby;
  this.user = {
    name: "Ray the Dummy",
    _id: "ray",
    phoneID: "asdasdasd" + Math.random() * 1000,
    won: 999,
    lost: 0,
    save: function() {}
  };
  this.lose = function() {
    return Client.lose.call(this);
  };
  this.draw = function() {
    return Client.lose.draw(this);
  };
  this.connection = {};
  x = 0;
  y = 0;
  this.connection.send = function(json) {
    var data;
    data = JSON.parse(json);
    switch (data.action) {
      case action.server.request:
        _this.status({
          action: action.client.accept
        });
        return _this.status({
          action: action.client.ready
        });
      case action.server.turn:
        return setTimeout(function() {
          return _this.status({
            action: action.client.endTurn,
            entities: [],
            x: 100,
            y: -100
          });
        }, 2000);
      case action.server.endTurn:
        x = -data.x;
        y = data.y;
        return setTimeout(function() {
          return _this.status({
            action: action.client.ready
          });
        }, 2000);
    }
  };
  return this;
};

lobby = [];

getLobbyNames = function(excludeID) {
  var client, _i, _len, _results;
  _results = [];
  for (_i = 0, _len = lobby.length; _i < _len; _i++) {
    client = lobby[_i];
    if (client.user.phoneID !== excludeID) {
      _results.push([client.user.name, client.user._id, client.user.won || 0, client.user.lost || 0]);
    }
  }
  return _results;
};

sendLobbyUpdate = function() {
  var client, names, _i, _len, _results;
  console.log(("[INFO|LOBBY] " + lobby.length + " clients are in the lobby: " + (getLobbyNames(null))).info);
  _results = [];
  for (_i = 0, _len = lobby.length; _i < _len; _i++) {
    client = lobby[_i];
    names = getLobbyNames(client.user.phoneID);
    _results.push(client.connection.send(JSON.stringify({
      action: action.server.lobbyUpdate,
      names: names
    })));
  }
  return _results;
};

getClientByName = function(name) {
  var client, _i, _len;
  for (_i = 0, _len = lobby.length; _i < _len; _i++) {
    client = lobby[_i];
    if (name === client.user.name) {
      return client;
    }
  }
};

getClientByID = function(id) {
  var client, _i, _len;
  for (_i = 0, _len = lobby.length; _i < _len; _i++) {
    client = lobby[_i];
    if (id === client.user._id + "") {
      return client;
    }
  }
};

Status = {
  unidentified: function(data) {
    var _this = this;
    if (data.action === action.client.setID) {
      return User.findOne({
        phoneID: data.id
      }, function(error, user) {
        if (error) {
          return console.log("[ERROR|GLOBAL] Mongo error while finding user".error);
        } else {
          if (user) {
            console.log(("[INFO|USER] Found the user " + user.name + " in the Database").info);
            _this.user = user;
            _this.status = Status.nowhere;
            return _this.connection.send(JSON.stringify({
              action: action.server.knownUser,
              name: _this.user.name
            }));
          } else {
            console.log("[INFO|USER] Could not find the user in the Database".info);
            _this.connection.send(JSON.stringify({
              action: action.server.unknownUser
            }));
            _this.user = new User({
              phoneID: data.id
            });
            return _this.status = Status.unnamed;
          }
        }
      });
    } else {
      return Status.error("unidentified", data, "unknown");
    }
  },
  unnamed: function(data) {
    switch (data.action) {
      case action.client.setName:
        this.setName(data.name);
        return this.status = Status.nowhere;
      default:
        return Status.error("unnamed", data, "unnamed");
    }
  },
  nowhere: function(data) {
    switch (data.action) {
      case action.client.setName:
        return this.setName(data.name);
      case action.client.goToLobby:
        console.log(("[INFO|CLIENT] " + this.user.name + " goes to the lobby").info);
        lobby.push(this);
        this.status = Status.lobby;
        return sendLobbyUpdate();
      default:
        return Status.general.call(this, "nowhere", data);
    }
  },
  lobby: function(data) {
    switch (data.action) {
      case action.client.setName:
        this.setName(data.name);
        return sendLobbyUpdate();
      case action.client.pair:
        console.log(("[INFO|LOBBY] " + this.user.name + " wants to pair with " + data.partner).info);
        if (data.partner === "ray") {
          this.partner = new Dummy();
        } else {
          this.partner = getClientByID(data.partner);
        }
        if (this.partner && !this.partner.partner && this.partner.status === Status.lobby) {
          this.partner.partner = this;
          return this.partner.connection.send(JSON.stringify({
            action: action.server.request,
            partner: this.user.name
          }));
        } else {
          this.connection.send(JSON.stringify({
            action: action.server.denied
          }));
          return this.partner = null;
        }
        break;
      case action.client.accept:
        console.log(("[INFO|LOBBY] " + this.partner.user.name + " has accepted").info);
        removeClient(this, lobby);
        removeClient(this.partner, lobby);
        sendLobbyUpdate();
        this.partner.connection.send(JSON.stringify({
          action: action.server.start
        }));
        this.status = Status.notMyTurn;
        return this.partner.status = Status.notMyTurn;
      case action.client.deny:
        console.log(("[INFO|LOBBY] " + this.partner.user.name + " has denied").info);
        this.partner.connection.send(JSON.stringify({
          action: action.server.denied
        }));
        this.partner.partner = void 0;
        this.partner = void 0;
        return sendLobbyUpdate();
      case action.client.leaveLobby:
        console.log(("[INFO|LOBBY] " + this.user.name + " leaves the lobby").info);
        removeClient(this, lobby);
        this.status = Status.nowhere;
        return sendLobbyUpdate();
      case action.client.goToLobby:
        return sendLobbyUpdate();
      default:
        return Status.general.call(this, "lobby", data);
    }
  },
  notMyTurn: function(data) {
    switch (data.action) {
      case action.client.ready:
        console.log(("[TURN|GAME] " + this.user.name + " is ready for another turn").turn);
        this.ready = true;
        if (this.partner && this.partner.ready) {
          console.log("[TURN|GAME] Initiated another turn.".turn);
          this.partner.connection.send(JSON.stringify({
            action: action.server.turn
          }));
          this.connection.send(JSON.stringify({
            action: action.server.turn
          }));
          this.partner.ready = false;
          this.ready = false;
          this.partner.status = Status.myTurn;
          this.status = Status.myTurn;
        }
        if (this.partner.lost) {
          console.log(("[INFO|GAME] " + this.user.name + " has found out that he won").info);
          return this.partner.lose();
        }
        break;
      case action.client.lose:
        console.log(("[INFO|GAME] " + this.user.name + " has announced that he lost").info);
        this.lost = true;
        this.ready = true;
        if (this.partner.ready) {
          if (this.partner.lost) {
            return this.draw();
          } else {
            return this.lose();
          }
        }
        break;
      default:
        return Status.general.call(this, "notMyTurn", data);
    }
  },
  myTurn: function(data) {
    switch (data.action) {
      case action.client.endTurn:
        console.log(("[TURN|GAME] " + this.user.name + " has ended his turn").turn);
        if (this.entityCache) {
          console.log(("[TURN|GAME] sending cached turn data to " + this.user.name).turn);
          this.connection.send(JSON.stringify(this.entityCache));
          this.entityCache = null;
        }
        data.action = action.server.endTurn;
        if (this.partner.status === Status.notMyTurn) {
          console.log(("[TURN|GAME] sending turn data to " + this.partner.user.name).turn);
          this.partner.connection.send(JSON.stringify(data));
        } else {
          console.log(("[TURN|GAME] caching turn data of " + this.partner.user.name).turn);
          this.partner.entityCache = data;
        }
        return this.status = Status.notMyTurn;
      case action.client.lose:
        console.log(("[INFO|GAME] " + this.user.name + " has resigned").info);
        return this.lose();
      default:
        return Status.general.call(this, "myTurn", data);
    }
  },
  gameOver: function(data) {
    switch (data.action) {
      case action.client.revenge:
        if (this.partner && this.partner.status === Status.gameOver) {
          console.log(("[INFO|GAMEOVER] " + this.user.name + " wants play again with " + this.partner.user.name).info);
          return this.partner.connection.send(JSON.stringify({
            action: action.server.request,
            partner: this.user.name
          }));
        } else {
          this.connection.send(JSON.stringify({
            action: action.server.denied
          }));
          return this.partner = null;
        }
        break;
      case action.client.leaveGameOver:
        console.log(("[INFO|GAMEOVER] " + this.user.name + " leaves the game over area").info);
        this.status = Status.nowhere;
        if (this.partner) {
          this.partner.connection.send(JSON.stringify({
            action: action.server.partnerLeftGameOver
          }));
        }
        return this.partner = null;
      case action.client.accept:
        console.log(("[INFO|LOBBY] " + this.partner.user.name + " has accepted").info);
        this.partner.connection.send(JSON.stringify({
          action: action.server.start
        }));
        this.turn = true;
        this.partner.turn = false;
        this.status = Status.notMyTurn;
        return this.partner.status = Status.notMyTurn;
      case action.client.deny:
        console.log(("[INFO|LOBBY] " + this.partner.user.name + " has denied").info);
        return this.partner.connection.send(JSON.stringify({
          action: action.server.denied
        }));
      case action.client.goToLobby:
        this.status = Status.lobby;
        return this.status(data);
      default:
        return Status.general.call(this, "gameOver", data);
    }
  },
  general: function(source, data) {
    switch (data.action) {
      case action.client.getName:
        console.log(("[INFO|CLIENT] Client " + this.user.name + " asked for his name").info);
        return this.connection.send(JSON.stringify({
          action: action.server.sendName,
          name: this.user.name
        }));
      default:
        return Status.error(source, data, this.user.name);
    }
  },
  error: function(status, data, name) {
    return console.log(("[ERROR|CLIENT] Client " + name + " has the status " + status + ". It can not receive the action " + data.action).error);
  }
};

User = mongoose.model('User', mongoose.Schema({
  name: String,
  phoneID: String,
  won: Number,
  lost: Number
}));

WebSocketServer = require('ws').Server;

wss = new WebSocketServer({
  port: config.port
});

mongoose.connect("mongodb://" + config.mongo_user + ":" + config.mongo_pw + "@localhost:" + config.mongo_port + "/" + config.mongo_name);

db = mongoose.connection;

db.on('error', console.error.bind(console, 'connection error:'));

wss.on("connection", function(ws) {
  console.log("[INFO|GLOBAL] A client connected.".info);
  clients.push(new Client(ws));
  return console.log(("[INFO|GLOBAL] Now there are " + clients.length + " clients online.").info);
});

lobby.push(new Dummy());

console.log(("[SERVER] The Server (re)started at " + (new Date())).server);

process.on('uncaughtException', function(err) {
  console.error(err);
  return console.log("[SERVER] Error caught by Batman. Node not exiting.".server);
});
