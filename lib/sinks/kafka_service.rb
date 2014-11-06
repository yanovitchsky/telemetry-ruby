require 'multi_json'
require 'poseidon'
require 'celluloid' unless defined?(::Goliath)

module Telemetry

  class KafkaServiceSink
    include Celluloid unless defined?(::Goliath)

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

    def is_evented?
      !defined?(::Goliath).nil? 
    end

    # Record the span.
    def record(span)
      data = {span: span.to_hash}
      is_evented? ? EM.defer{send_message(:span, data)} : async.send_message(:span, data)
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
      is_evented? ? EM.defer{send_message(:annotation, data)} : async.send_message(:annotation, data)
    end

    def send_message(type, data)
      begin
        messages = []
        messages << Poseidon::MessageToSend.new(@telemetry_topic, MultiJson.dump(data))
        p messages
        @producer.send_messages(messages)
        @logger.info  "publishing #{messages} to kafka on #{@telemetry_topic}"
      rescue Exception => e
        @logger.info("Error logging #{type.to_s}: #{e}")
      end
    end
  end
end