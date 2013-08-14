require 'net/http'
require 'yajl'

module Telemetry
  class TelemetryServiceSink
    def initialize(service_host, service_port)
      @http = Net::HTTP.new(service_host, service_port)
    end

    # Record the span.
    def record(span)
      Rails.logger.debug "Logging span: #{span.inspect}"
      @http.post('/spans',
                 Yajl::Encoder.encode(span),
                 {'Content-Type' => 'application/json', 'Accept' => 'application/json'})
    end

    # Record the annotation.
    def record_annotation(trace_id, id, annotation_data)
      Rails.logger.debug "Logging annotation: #{annotation_data.inspect}"
      @http.post("/spans/#{trace_id}/#{id}",
                 Yajl::Encoder.encode(annotation_data),
                 {'Content-Type' => 'application/json', 'Accept' => 'application/json'})
    end
  end
end