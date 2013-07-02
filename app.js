// Generated by CoffeeScript 1.6.3
(function() {
  var Client, Dummy, Status, User, WebSocketServer, action, clients, colors, config, db, getClientByName, getLobbyNames, lobby, mongoose, removeClient, sendLobbyUpdate, wss;

  config = require("./config.json");

  action = require("./action.json");

  colors = require('colors');

  mongoose = require("mongoose");

  colors.setTheme({
    info: 'white',
    turn: 'grey',
    warn: 'yellow',
    debug: 'magenta',
    error: 'red'
  });

  WebSocketServer = require('ws').Server;

  wss = new WebSocketServer({
    port: config.port
  });

  mongoose.connect("mongodb://" + config.mongo_user + ":" + config.mongo_pw + "@localhost:" + config.mongo_port + "/" + config.mongo_name);

  db = mongoose.connection;

  db.on('error', console.error.bind(console, 'connection error:'));

  User = mongoose.model('User', mongoose.Schema({
    name: String,
    phoneID: String,
    won: Number,
    lost: Number
  }));

  clients = [];

  lobby = [];

  removeClient = function(toRemove, array) {
    var client, i, _i, _len;
    i = 0;
    for (_i = 0, _len = array.length; _i < _len; _i++) {
      client = array[_i];
      if (client.user.phoneID === toRemove.user.phoneID) {
        return array.splice(i, 1);
      }
      i++;
    }
  };

  getLobbyNames = function(excludeID) {
    var client, _i, _len, _results;
    _results = [];
    for (_i = 0, _len = lobby.length; _i < _len; _i++) {
      client = lobby[_i];
      if (client.user.phoneID !== excludeID) {
        _results.push([client.user.name, client.user.won || 0, client.user.lost || 0]);
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
        return Status.error("unidentified", data);
      }
    },
    unnamed: function(data) {
      switch (data.action) {
        case action.client.setName:
          this.user.name = data.name;
          this.status = Status.nowhere;
          this.connection.send(JSON.stringify({
            action: action.server.confirm,
            name: this.user.name
          }));
          console.log(("[INFO|CLIENT] A client set its name to " + this.user.name).info);
          return this.user.save();
        default:
          return Status.error("unnamed", data);
      }
    },
    nowhere: function(data) {
      switch (data.action) {
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
        case action.client.pair:
          console.log(("[INFO|LOBBY] " + this.user.name + " wants to pair with " + data.partner).info);
          if (data.partner === "Ray the Dummy") {
            this.partner = new Dummy();
          } else {
            this.partner = getClientByName(data.partner);
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
          this.turn = true;
          this.partner.turn = false;
          this.status = Status.ingame;
          return this.partner.status = Status.ingame;
        case action.client.deny:
          console.log(("[INFO|LOBBY] " + this.partner.user.name + " has denied").info);
          this.partner.connection.send(JSON.stringify({
            action: action.server.denied
          }));
          this.partner.partner = void 0;
          this.partner = void 0;
          return sendLobbyUpdate();
        case action.client.goToLobby:
          return sendLobbyUpdate();
        default:
          return Status.general.call(this, "lobby", data);
      }
    },
    ingame: function(data) {
      switch (data.action) {
        case action.client.turn:
          if (this.turn) {
            this.turn = false;
            this.partner.turn = true;
            console.log(("[TURN|GAME] " + this.user.name + " has made his turn").turn);
            return this.partner.connection.send(JSON.stringify({
              action: action.server.turn,
              x: data.x,
              y: data.y
            }));
          } else {
            return console.log(("[WARNING|GAME] Client " + this.user.name + " tried to have a turn although his partner is it").warn);
          }
          break;
        case action.client.lose:
          console.log(("[INFO|GAME] " + this.user.name + " has announced that he lost").info);
          console.log(("[INFO|GAME] " + this.partner.user.name + " has won the game against " + this.user.name).info);
          this.partner.connection.send(JSON.stringify({
            action: action.server.youWin
          }));
          this.partner.status = Status.nowhere;
          this.status = Status.nowhere;
          this.partner.partner = void 0;
          return this.partner = void 0;
        default:
          return Status.general.call(this, "ingame", data);
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
          return Status.error(source, data);
      }
    },
    error: function(status, data) {
      return console.log(("[ERROR|CLIENT] Client has the status " + status + ". It can not receive the action " + data.action).error);
    }
  };

  Dummy = function() {
    var _this = this;
    this.partner = void 0;
    this.status = Status.lobby;
    this.user = {
      name: "Ray the Dummy",
      phoneID: "asdasdasd" + Math.random() * 1000,
      won: 999,
      lost: 0
    };
    this.connection = {};
    this.connection.send = function(json) {
      var data;
      data = JSON.parse(json);
      switch (data.action) {
        case action.server.request:
          _this.status({
            action: action.client.accept
          });
          return setTimeout(function() {
            return _this.status({
              action: action.client.turn,
              x: 100,
              y: -100
            });
          }, 5000);
        case action.server.turn:
          return _this.status({
            action: action.client.turn,
            x: data.x,
            y: data.y
          });
      }
    };
    return this;
  };

  Client = function(connection) {
    var _this = this;
    this.connection = connection;
    this.partner = void 0;
    this.user = void 0;
    this.status = Status.unidentified;
    this.turn = false;
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

  wss.on("connection", function(ws) {
    console.log("[INFO|GLOBAL] A client connected.".info);
    clients.push(new Client(ws));
    return console.log(("[INFO|GLOBAL] Now there are " + clients.length + " clients online.").info);
  });

  lobby.push(new Dummy());

  process.on('uncaughtException', function(err) {
    console.error(err);
    return console.log("Error caught by Batman. Node not exiting.");
  });

}).call(this);
