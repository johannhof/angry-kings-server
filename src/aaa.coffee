# Configuration and action code JSON files
# not included in Git because hackers.
config = require "./config.json"
action = require "./action.json"

colors = require 'colors'
mongoose = require "mongoose"

colors.setTheme {
  info: 'white',
  turn: 'grey',
  warn: 'yellow',
  debug: 'magenta',
  error: 'red',
  server: 'green'
}
