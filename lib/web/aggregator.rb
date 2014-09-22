require 'em-mongo'
require 'eventmachine'
require 'yajl'

module Telemetry
  class Aggregator
    class Handler < ::EM::Connection
      def initialize(config)
        host = config['session']['default']['hosts'].first.split(':').first
        port = config['session']['default']['hosts'].first.split(':').last
        database = config['session']['default']['database']
        @db = EM::Mongo::Connection.new(host, port).db(database)
      end

      def receive_data(data)
        p data
        store(data)
      end

      private
      def store(data)
        decoded_data = Yajl::Decoder(data)
        case decoded_data.keys.first
        when :span 
          save_span(decoded_data[:span])
        when :annotation
          save_annotation(decoded_data[:annotation])
                        
      end

      def save_span(data)
        save('spans', data)
      end

      def save_annotation(data)
        save('annotations', data)
      end

      def save(collection, data)
        coll= @db.collection(collection)
        coll.insert data
      end
    end

    def initialize(host, port, mongo_config)
      @host = host
      @port = port
      @mongo_config = mongo_config
    end

    def run
      ::EM.run do
        ::EM.open_datagram_socket(@host, @port, Handler, @mongo_config)
      end
    end
  end
end