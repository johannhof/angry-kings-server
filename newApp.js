// Generated by CoffeeScript 1.6.1
(function() {
  var Client, Status, WebSocketServer, clients, getClientByName, getLobbyNames, lobby, sendLobbyUpdate, wss;

  WebSocketServer = require('ws').Server;

  wss = new WebSocketServer({
    port: 61224
  });

  lobby = [];

  clients = [];

  getLobbyNames = function() {
    var client, _i, _len, _results;
    _results = [];
    for (_i = 0, _len = lobby.length; _i < _len; _i++) {
      client = lobby[_i];
      _results.push(client.name);
    }
    return _results;
  };

  sendLobbyUpdate = function() {
    var client, names, _i, _len, _results;
    names = getLobbyNames();
    _results = [];
    for (_i = 0, _len = lobby.length; _i < _len; _i++) {
      client = lobby[_i];
      _results.push(client.connection.send(JSON.stringify({
        action: "lobbyUpdate",
        names: names
      })));
    }
    return _results;
  };

  getClientByName = function(name) {
    var client, _i, _len;
    for (_i = 0, _len = lobby.length; _i < _len; _i++) {
      client = lobby[_i];
      if (name === client.name) {
        return client;
      }
    }
  };

  Status = {
    unidentified: function(data) {
      switch (data.action) {
        case "name":
          this.name = data.value;
          return console.log("A client set its name to " + this.name);
        default:
          return Status.unrecognized("unidentified", data);
      }
    },
    nowhere: function(data) {
      switch (data.action) {
        case "lobby":
          console.log("" + this.name + " goes to the lobby");
          lobby.push(this);
          return sendLobbyUpdate();
        default:
          return Status.unrecognized("nowhere", data);
      }
    },
    lobby: function(data) {
      switch (data.action) {
        case "pair":
          console.log("" + this.name + " wants to pair with " + data.partner);
          this.partner = getClientByName(data.partner);
          this.partner.partner = this;
          lobby.splice(lobby.indexOf(this, 1));
          lobby.splice(lobby.indexOf(this.partner, 1));
          return this.partner.connection.send(JSON.stringify({
            action: "request",
            partner: this.name
          }));
        case "accept":
          console.log("" + this.partner.name + " has accepted");
          return this.partner.connection.send(JSON.stringify({
            action: "start"
          }));
        case "deny":
          console.log("" + this.partner.name + " has denied");
          this.partner.connection.send(JSON.stringify({
            action: "denied"
          }));
          lobby.push(this);
          lobby.push(this.partner);
          this.partner.partner = void 0;
          this.partner = void 0;
          return sendLobbyUpdate();
        default:
          return Status.unrecognized("lobby", data);
      }
    },
    ingame: function(data) {
      switch (data.action) {
        case "lobby":
          console.log("" + this.name + " goes to the lobby");
          lobby.push(this);
          return sendLobbyUpdate();
        default:
          return Status.unrecognized("nowhere", data);
      }
    },
    unrecognized: function(status, data) {
      return console.log("Client has the status " + status + ". It can not receive the action " + data.action);
    }
  };

  Client = function(connection) {
    var _this = this;
    this.connection = connection;
    this.partner = void 0;
    this.name = void 0;
    this.status = Status.unidentified;
    this.connection.on('close', function() {
      console.log("" + _this.name + " disconnected");
      lobby.splice(lobby.indexOf(self), 1);
      return console.log("Now there are " + clients.length + " clients online.");
    });
    return this.connection.on('message', function(message) {
      var data;
      try {
        data = JSON.parse(message);
        if (data != null ? data.action : void 0) {
          return _this.status(data);
        }
      } catch (e) {
        return console.log("Error parsing " + message + ": " + e);
      }
    });
  };

}).call(this);
