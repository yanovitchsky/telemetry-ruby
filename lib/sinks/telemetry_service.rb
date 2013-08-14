require 'net/http'
require 'yajl'

module Telemetry
  class TelemetryServiceSink
    def initialize(service_host, service_port)
      @http = Net::HTTP.new(service_host, service_port)
    end

    # Record the span.
    def record(span)
      begin
        @http.post('/spans',
                   Yajl::Encoder.encode(span),
                   {'Content-Type' => 'application/json', 'Accept' => 'application/json'})
      rescue Exception => e
        Rails.logger.info "Error logging span: #{e}"
      end
    end

    # Record the annotation.
    def record_annotation(trace_id, id, annotation_data)
      begin
        @http.post("/spans/#{trace_id}/#{id}",
                   Yajl::Encoder.encode(annotation_data),
                   {'Content-Type' => 'application/json', 'Accept' => 'application/json'})
      rescue Exception => e
        Rails.logger.info "Error logging annotation: #{e}"
      end
    end
  end
end