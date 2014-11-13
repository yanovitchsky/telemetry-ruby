require 'multi_json'
require 'poseidon'
require 'celluloid' unless defined?(::Goliath)

module Telemetry

  class KafkaServiceSink
    extend Forwardable

    attr_accessor :proxy

    def_delegators :proxy, :record, :record_annotation
    
    def initialize(logger)
      @proxy = defined?(::Goliath).nil? ? AsyncKafkaSink.new(logger) : EventedKafkaSink.new(logger)
    end
  end

  class KafkaSinker

      KAFKA_HOST = {
        'development' => "192.168.60.11:9092",
        'production'  => "192.168.60.11:9092"
      }
      def initialize(logger) 
        env = ENV['RAILS_ENV'] || ENV['RACK_ENV'] || ENV['KARIBU_ENV'] || 'development'
        @logger = logger
        @telemetry_topic = (env == "production") ? "telemetry" : "telemetry-test"
        @producer = Poseidon::Producer.new([KAFKA_HOST[env]], "telemetry_producer")
      end

      # Record the span.
      def record(span)
        data = {span: span.to_hash}
        send_message(:span, data)
      end

      # Record the annotation.
      def record_annotation(trace_id, id, annotation_data)
        data ={
          annotation: {
            trace_id: trace_id,
            span_id: id,
            data: annotation_data.to_hash
          }
        }
        send_message(:annotation, data)
      end

      def send_message(type, data)
        begin
          messages = []
          messages << Poseidon::MessageToSend.new(@telemetry_topic, MultiJson.dump(data))
          @producer.send_messages(messages)
        rescue Exception => e
          @logger.error("Error logging #{type.to_s}: #{e}")
        end
      end
    end

  class AsyncKafkaSink
    
    def initialize(logger)
      KafkaSinker.class_eval do
        include Celluloid
      end

      @pool =  KafkaSinker.pool(size: 100, args: [logger])
    end

    # record span
    def record(span)
      @pool.async.record(span)
    end

    # Record the annotation.
    def record_annotation(trace_id, id, annotation_data)
      @pool.async.record_annotation(trace_id, id, annotation_data)
    end
  end

  class EventedKafkaSink
    def initialize(logger)
      @sinker = KafkaSinker.new(logger)
    end

    # record span
    def record(span)
      if EM.reactor_running?
        EM.defer{@sinker.record(span)}
      end
    end

    # Record the annotation.
    def record_annotation(trace_id, id, annotation_data)
      if EM.reactor_running?
        EM.defer{@sinker.record_annotation(trace_id, id, annotation_data)}
      end
    end
  end
end
