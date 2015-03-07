# craft_client
Ruby client library for the ['Craft' Minecraft clone](https://github.com/fogleman/Craft)

## Installation
Add

    gem 'craft_client'

to your application's Gemfile, or run

    gem install craft_client

## Basic usage example
Require the library

    require 'craft_client'

Create a new Server object;

    server = CraftClient::Server.new(USERNAME, IDENTITY_TOKEN, SERVER_NAME, SERVER_PORT)

Attempt to connect to the server;

    server.connect

Send a chat message;

    server.send_chat_message('Hello world!')

Disconnect;

    server.disconnect

## Server events
To receive events from the server (new chat messages, block changes, etc), call server.get_event

    event = server.get_event

server.get_event blocks until it receives an event, from where it'll return a hash with the event data. If craft_client is unable to understand the message, it will return nil.

* Chat message
  - type: :chat_message
  - sender: Username of message author
  - message: Message
* Special chat message (typically server broadcasts)
  - type: :chat_special
  - message: Message
* Block change
  - type: :block_change
  - pos: [x, y, z]
  - id: New block ID
* Sign change
  - type: :sign_update
  - pos: [x, y, z]
  - facing: Sign direction
  - text: Sign text
* Player join
  - type: :player_join
  - id: Local ID of player
  - name: Player username
* Player position
  - type: :player_position
  - id: Local ID of player
  - pos: [x, y, z]
* Player leave
  - type: :player_leave
  - id: Local ID of player
  - name: Player username
