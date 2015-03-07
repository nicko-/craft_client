module CraftClient
  class Server
    attr_accessor :block_cache
    attr_reader :username, :players

    def initialize(username, identity_token, server_name, server_port)
      @username = username
      @identity_token = identity_token

      @server_name = server_name
      @server_port = server_port
      @block_cache = {}
      @players = {}

      @write_mutex = Mutex.new

      @buffer = ''

      @tcp = nil
    end

    def connect
      # Authenticate with craft.michaelfogleman.com
      uri = URI.parse('https://craft.michaelfogleman.com/api/1/identity')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      response = http.post(uri.request_uri, "username=#{@username}&identity_token=#{@identity_token}")
      server_token = response.body.chomp
      fail 'Could not authenticate!' if server_token.length != 32

      # Connect and authenticate with the server
      @tcp = TCPSocket.new(@server_name, @server_port)
      @tcp.puts("A,#{@username},#{server_token}")
    end

    def get_event
      # Blocks and returns an event hash
      data = @tcp.gets.chomp.split(',')

      case data[0]
      when 'T'            # Chat message
        message_contents = data[1 .. -1].join(',')
        if !message_contents.split('>')[1].nil? # If message was said by player
          return { type: :chat_message, sender: message_contents.split('>')[0], message: message_contents.split('>')[1 .. -1].join('>').lstrip }
        else
          return { type: :chat_special, message: message_contents }
        end
      when 'B'            # Block change
        pos = [data[3].to_i, data[4].to_i, data[5].to_i] # Create the position data
        return nil if data[1].to_i != pos[0] / CHUNK_SIZE || data[2].to_i != pos[2] / CHUNK_SIZE
        @block_cache[pos] = data[6].to_i
        return { type: :block_change, pos: pos, id: data[6].to_i }
      when 'S'            # Sign change
        return { type: :sign_update, pos: [data[3].to_i, data[4].to_i, data[5].to_i], facing: data[6].to_i, text: (data[7..-1] || []).join(',') }
      when 'N'            # Player join
        prepare_player(data[1].to_i)
        @players[data[1].to_i][:name] = data[2..-1].join(',')
        return { type: :player_join, id: data[1].to_i, name: data[2..-1].join(',') }
      when 'P'            # Player position
        prepare_player(data[1].to_i)
        @players[data[1].to_i][:pos] = data[2..-1].map(&:to_f)
        return { type: :player_position, id: data[1].to_i, pos: @players[data[1].to_i][:pos] }
      when 'D'            # Player leave
        event = { type: :player_leave, id: data[1].to_i, name: @players[data[1].to_i][:name] }
        @players.delete(data[1].to_i)
        return event
      else
        return nil
      end
    end

    def get_block(x, y, z)     # get_block_at
      # Return block if it exists in cache
      return @block_cache[[x, y, z]] unless @block_cache[[x, y, z]].nil?

      # Otherwise, request the chunk the block is in.
      @write_mutex.synchronize do
        chunk_x = (x / CHUNK_SIZE).floor
        chunk_z = (z / CHUNK_SIZE).floor
        @tcp.puts("C,#{chunk_x},#{chunk_z}")
        @tcp.flush

        # Keep mutex locked to stop other threads requesting from server
        loop do
          data = @tcp.gets.chomp.split(',')
          if data[0] == 'B'
            @block_cache[[data[3].to_i, data[4].to_i, data[5].to_i]] = data[6].to_i
          elsif data[0] == 'C'
            break
          end
        end
      end

      @block_cache[[x, y, z]]
    end

    def set_block(x, y, z, id) # set_block
      @block_cache[[x, y, z]] = id
      @write_mutex.synchronize do
        @buffer += "B,#{x},#{y},#{z},#{id}\n"
      end
    end

    def flush_buffer
      @write_mutex.synchronize do
        @tcp.write(@buffer)
        @tcp.flush
        @buffer = ''
      end
    end

    def send_chat_message(message)
      @write_mutex.synchronize do
        message.lines.each do |line|
          @buffer += "T,#{line.chomp}\n"
        end
      end
    end

    def send_private_message(player, message)
      @write_mutex.synchronize do
        message.lines.each do |line|
          @buffer += "T,@#{player} #{line.chomp}\n"
        end
      end
    end

    def set_sign(x, y, z, facing, text)
      @write_mutex.synchronize do
        @buffer += "S,#{x},#{y},#{z},#{facing},#{text}\n"
      end
    end

    def set_position(x, y, z, rotate_x, rotate_y)
      @write_mutex.synchronize do
        @buffer += "P,#{x.to_f},#{y.to_f},#{z.to_f},#{rotate_x.to_f},#{rotate_y.to_f}\n"
      end
    end

    def set_light(x, y, z, light)
      @write_mutex.synchronize do
        @buffer += "L,#{x},#{y},#{z},#{light}\n"
      end
    end

    def disconnect
      @tcp.close unless @tcp.nil?
    end

    private

    def prepare_player(id)
      @players[id] = { name: nil, pos: nil } if @players[id].nil?
    end
  end
end
