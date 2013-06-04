var WebSocketServer = require('ws').Server,
    wss = new WebSocketServer({port : 61224}),
    lobby = [], clients = [];

function getLobbyNames() {
    var names = "", i;
    for(i = 0; i < lobby.length; i++) {
        names += lobby[i].name + ",";
    }
    return names;
}

function sendLobbyUpdate() {
    var names = getLobbyNames(), i;
    for(i = 0; i < lobby.length; i++) {
        lobby[i].connection.send(JSON.stringify({action : "lobbyUpdate", names : names}));
    }
}

function getClientByName(name) {
    var i;
    for(i = 0; i < clients.length; i++) {
        if(clients[i].name === name) {
            return clients[i];
        }
    }
    return undefined;
}

var Client = function (myConnection) {
    this.connection = myConnection;
    this.partner = undefined;
    this.name = undefined;
    var self = this;
    this.connection.on('close', function () {
        console.log(self.name + ' disconnected');
        lobby.splice(lobby.indexOf(self), 1);
        clients.splice(clients.indexOf(self), 1);
        console.log('Now there are ' + clients.length + ' clients online.');
    });
    this.connection.on('message', function (message) {
        var data = JSON.parse(message);
        if(data.action === "name") {
            self.name = data.value;
            console.log('A client set its name to: %s', self.name);
            lobby.push(self);
            sendLobbyUpdate();
            return;
        }
        if(data.action === "lobby") {
            console.log(self.name + " goes to the lobby.");
            lobby.push(self);
            sendLobbyUpdate();
            return;
        }
        if(data.action === "pair") {
            console.log(self.name + " wants to pair with " + data.partner);
            self.partner = getClientByName(data.partner);
            self.partner.partner = self;
            lobby.splice(lobby.indexOf(self), 1);
            lobby.splice(lobby.indexOf(self.partner), 1);
            self.partner.connection.send(JSON.stringify({action : "request", partner : self.name}));
            return;
        }
        if(data.action === "accept") {
            console.log(self.partner.name + " has accepted");
            self.partner.connection.send(JSON.stringify({action : "start"}));
            return;
        }
        if(data.action === "deny") {
            console.log(self.partner.name + " has denied");
            self.partner.connection.send(JSON.stringify({action : "denied"}));
            lobby.push(self);
            lobby.push(self.partner);
            self.partner.partner = undefined;
            self.partner = undefined;
            sendLobbyUpdate();
            return;
        }
        if(data.action === "turn") {
            console.log(self.name + " has made his turn");
            self.partner.connection.send(JSON.stringify({action : "turn"}));
        }
    });
};

wss.on('connection', function (ws) {
    console.log('A client connected.');
    var client = new Client(ws);
    clients.push(client);
    console.log('Now there are ' + clients.length + ' clients online.');
    console.log(lobby.length + ' in the lobby.');
});