
WebSocketServer = require('ws').Server
wss = new WebSocketServer({port: config.port})

mongoose.connect "mongodb://#{config.mongo_user}:#{config.mongo_pw}@localhost:#{config.mongo_port}/#{config.mongo_name}"

db = mongoose.connection
db.on 'error', console.error.bind(console, 'connection error:')

# starting point for each connection
wss.on "connection", (ws) ->
  console.log "[INFO|GLOBAL] A client connected.".info
  clients.push new Client(ws)
  console.log "[INFO|GLOBAL] Now there are #{clients.length} clients online.".info

# DUMMY PARTNER FOR TESTING
lobby.push new Dummy()

# Say Hello World
console.log "[SERVER] The Server (re)started at #{new Date()}".server

# catches all other exceptions and prevents the server from crashing
process.on 'uncaughtException', (err) ->
  console.error err
  console.log "[SERVER] Error caught by Batman. Node not exiting.".server
