require 'multi_json'
require 'poseidon'
require 'celluloid'

module Telemetry
  class KafkaServiceSink
    include Celluloid

    KAFKA_HOST = {
      'development' => "10.10.42.8:9092",
      'production'  => "192.168.100.1:9092"
    }

    TELEMETRY_TOPIC = "telemetry"

    def initialize(logger)
      env = ENV['RAILS_ENV'] || ENV['RACK_ENV'] || ENV['KARIBU_ENV'] || 'development'
      @logger = logger
      partitionner = Proc.new{|key, partition_count| p "key: #{key} === partition_count: #{partition_count}"; 0}
      @producer = Poseidon::Producer.new([KAFKA_HOST[env]], "telemetry_producer")
    end

    # Record the span.
    def record(span)
      data = {span: span.to_hash}
      async.send_message(:span, data)
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
      async.send_message(:annotation, data)
    end

    def send_message(type, data)
      begin
        messages = []
        messages << Poseidon::MessageToSend.new(TELEMETRY_TOPIC, MultiJson.dump(data))
        @producer.send_messages(messages)
        @logger.info  "publishing #{messages} to kafka on #{TELEMETRY_TOPIC}"
      rescue Exception => e
        @logger.info("Error logging #{type.to_s}: #{e}")
      end
    end
  end
end