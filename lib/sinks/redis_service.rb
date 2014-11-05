require 'redis' if defined?(::Redis)
require 'multi_json'

module Telemetry
  class RedisServiceSink
    
    # host: redis host
    # port: redis port
    # logger: logger object
    # service : service name loggin
    def initialize(host, port, logger, service)
      @redis = Redis.new(host: host, port: port)
      @logger = logger
      @service = service
    end
    # Record the span.
    def record(span)
      begin
        data = {span: span.to_hash}
        key = "telemetry.#{@service}.span"
        @redis.publish(key, MultiJson.dump(data))
        @logger.info  "publishing #{data.inspect} to #{key}"
      rescue Exception => e
        @logger.info("Error logging span: #{e}")
      end
      
    end

    # Record the annotation.
    def record_annotation(trace_id, id, annotation_data)
      begin
         data ={
          annotation: {
            trace_id: trace_id,
            span_id: id,
            data: annotation_data.to_hash
          }
        }
        key = "telemetry.#{@service}.anno"
        @redis.publish(key, MultiJson.dump(data))
        @logger.info  "publishing #{data.inspect} to #{key}"
      rescue Exception => e
        @logger.info "Error logging annotation: #{e}"
      end
    end
  end
end