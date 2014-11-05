require 'socket'
require 'multi_json'

module Telemetry
  class UdpServiceSink

    EOF = "__EOF__\r\n"
    
    def initialize(host, port, logger)
      @socket = UDPSocket.new
      @socket.connect(host, port)
      @logger = logger
    end
    # Record the span.
    def record(span)
      data = {span: span.to_hash}
      encoded_data = MultiJson.dump(data)
      begin
        @socket.send(encoded_data, 0)
      rescue Exception => e
        @logger.info "error send span #{e}"
      end
    end

    # Record the annotation.
    def record_annotation(trace_id, id, annotation_data)
      data ={
        annotation: {
          trace_id: trace_id,
          id: id,
          data: annotation_data.to_hash
        }
      }
      encoded_data = MultiJson.dump(data) + EOF
      begin
        @socket.send(encoded_data, 0)
      rescue Exception => e
         @logger.info "error sending annotation #{e}" 
      end
    end
  end
end