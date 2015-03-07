require 'minitest/spec'
require 'minitest/autorun'

require 'stringio'

require_relative '../lib/craft_client'

class BidirectionalStringIO
  attr_accessor :in_io, :out_io

  def initialize
    @in_io = StringIO.new
    @out_io = StringIO.new
  end

  def write(str)
    @out_io.write(str)
  end

  def print(str)
    write(str)
  end

  def puts(str)
    print("#{str}\n")
  end

  def read(bytes)
    @in_io.read(bytes)
  end

  def gets
    @in_io.gets
  end

  def flush; end
end

describe CraftClient::Server do
  it 'can correctly handle a server special message' do
    server = CraftClient::Server.new('', '', '', 0)
    io = StringIO.new("T,abc,def\n")
    server.instance_variable_set(:@tcp, io)
    server.get_event.must_equal(type: :chat_special, message: 'abc,def')
  end

  it 'can correctly handle a player chat message' do
    server = CraftClient::Server.new('', '', '', 0)
    io = StringIO.new("T,player> test,test123>a\n")
    server.instance_variable_set(:@tcp, io)
    server.get_event.must_equal(type: :chat_message, sender: 'player', message: 'test,test123>a')
    io = StringIO.new("T,player> test,test123\n")
    server.instance_variable_set(:@tcp, io)
    server.get_event.must_equal(type: :chat_message, sender: 'player', message: 'test,test123')
  end

  it 'can correctly handle a block change' do
    server = CraftClient::Server.new('', '', '', 0)
    io = StringIO.new("B,0,0,1,1,1,5\n")
    server.instance_variable_set(:@tcp, io)
    server.get_event.must_equal(type: :block_change, pos: [1, 1, 1], id: 5)
  end

  it 'can correctly handle a block change double-notify' do
    server = CraftClient::Server.new('', '', '', 0)
    io = StringIO.new("B,1,1,1,1,1,5\n")
    server.instance_variable_set(:@tcp, io)
    server.get_event.must_equal(nil)
  end

  it 'can correctly handle a sign update' do
    server = CraftClient::Server.new('', '', '', 0)
    io = StringIO.new("S,0,0,1,1,1,4,test,test\n")
    server.instance_variable_set(:@tcp, io)
    server.get_event.must_equal(type: :sign_update, pos: [1, 1, 1], facing: 4, text: 'test,test')
  end

  it 'can correctly handle a player joining' do
    server = CraftClient::Server.new('', '', '', 0)
    io = StringIO.new("N,1,test,test\n")
    server.instance_variable_set(:@tcp, io)
    server.get_event.must_equal(type: :player_join, id: 1, name: 'test,test')
    server.players[1].must_equal(name: 'test,test', pos: nil)
  end

  it 'can correctly handle a player moving' do
    server = CraftClient::Server.new('', '', '', 0)
    io = StringIO.new("P,1,1.0,2.0,3.0,4.0,5.0\n")
    server.instance_variable_set(:@tcp, io)
    server.get_event.must_equal(type: :player_position, id: 1, pos: [1.0, 2.0, 3.0, 4.0, 5.0])
    server.players[1].must_equal(name: nil, pos: [1.0, 2.0, 3.0, 4.0, 5.0])
  end

  it 'can correctly handle a player moving before joining' do
    server = CraftClient::Server.new('', '', '', 0)
    io = StringIO.new("P,1,1.0,2.0,3.0,4.0,5.0\nN,1,test,test")
    server.instance_variable_set(:@tcp, io)
    server.get_event.must_equal(type: :player_position, id: 1, pos: [1.0, 2.0, 3.0, 4.0, 5.0])
    server.get_event.must_equal(type: :player_join, id: 1, name: 'test,test')
    server.players[1].must_equal(name: 'test,test', pos: [1.0, 2.0, 3.0, 4.0, 5.0])
  end

  it 'can correctly handle a player leaving' do
    server = CraftClient::Server.new('', '', '', 0)
    io = StringIO.new("N,1,test,test\nD,1\n")
    server.instance_variable_set(:@tcp, io)
    server.get_event
    server.get_event.must_equal(type: :player_leave, id: 1, name: 'test,test')
    server.players[1].must_equal(nil)
    server.players.length.must_equal(0)
  end

  it 'can correctly handle itself joining' do
    server = CraftClient::Server.new('', '', '', 0)
    io = StringIO.new("N,1,guest1\nN,1,test,test\n")
    server.instance_variable_set(:@tcp, io)
    server.get_event.must_equal(type: :player_join, id: 1, name: 'guest1')
    server.get_event.must_equal(type: :player_join, id: 1, name: 'test,test')
    server.players[1].must_equal(name: 'test,test', pos: nil)
    server.players.length.must_equal 1
  end

  it 'can retrieve a block from the server when not in cache' do
    server = CraftClient::Server.new('', '', '', 0)
    bidir_io = BidirectionalStringIO.new
    bidir_io.in_io = StringIO.new("B,0,0,5,5,5,10\nC,0,0\n")
    server.instance_variable_set(:@tcp, bidir_io)
    server.get_block(5, 5, 5).must_equal 10
    bidir_io.out_io.string.must_equal "C,0,0\n"
  end

  it 'can retrieve a block from the server when in cache' do
    server = CraftClient::Server.new('', '', '', 0)
    server.instance_variable_set(:@block_cache, { [5, 5, 5] => 10 })
    server.get_block(5, 5, 5).must_equal 10
  end

  it 'can set a block' do
    server = CraftClient::Server.new('', '', '', 0)
    server.set_block(5, 5, 5, 10)
    server.instance_variable_get(:@buffer).must_equal "B,5,5,5,10\n"
  end

  it 'can flush the buffer correctly' do
    server = CraftClient::Server.new('', '', '', 0)
    bidir_io = BidirectionalStringIO.new
    server.instance_variable_set(:@tcp, bidir_io)
    server.set_block(5, 5, 5, 10)
    server.flush_buffer
    bidir_io.out_io.string.must_equal "B,5,5,5,10\n"
  end

  it 'can send a chat message' do
    server = CraftClient::Server.new('', '', '', 0)
    server.send_chat_message('test')
    server.instance_variable_get(:@buffer).must_equal "T,test\n"
  end

  it 'can send a multiline chat message' do
    server = CraftClient::Server.new('', '', '', 0)
    server.send_chat_message("test\ntest\n")
    server.instance_variable_get(:@buffer).must_equal "T,test\nT,test\n"
  end

  it 'can send a private message' do
    server = CraftClient::Server.new('', '', '', 0)
    server.send_private_message('test_player', 'test')
    server.instance_variable_get(:@buffer).must_equal "T,@test_player test\n"
  end

  it 'can send a multiline private message' do
    server = CraftClient::Server.new('', '', '', 0)
    server.send_private_message('test_player', "test\ntest\n")
    server.instance_variable_get(:@buffer).must_equal "T,@test_player test\nT,@test_player test\n"
  end

  it 'can set a sign' do
    server = CraftClient::Server.new('', '', '', 0)
    server.set_sign(5, 5, 5, 6, 'test')
    server.instance_variable_get(:@buffer).must_equal "S,5,5,5,6,test\n"
  end

  it 'can set position' do
    server = CraftClient::Server.new('', '', '', 0)
    server.set_position(1.2, 2.3, 3.4, 4.5, 5.6)
    server.instance_variable_get(:@buffer).must_equal "P,1.2,2.3,3.4,4.5,5.6\n"
  end

  it 'can set light values' do
    server = CraftClient::Server.new('', '', '', 0)
    server.set_light(5, 4, 3, 15)
    server.instance_variable_get(:@buffer).must_equal "L,5,4,3,15\n"
  end
end
