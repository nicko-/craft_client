module CraftClient
  NAME = 'CraftClient'
  VERSION = '0.0.1'

  CHUNK_SIZE = 32
end

require 'net/http'
require 'socket'

require_relative 'craft_client/server'
