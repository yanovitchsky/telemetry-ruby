require 'net/http'
require 'yajl'

module Telemetry
  class TelemetryServiceSink
    attr_reader :service_host_port

    def initialize(service_host_port)
      # TODO: Eventually this needs to come from some sort of configuration.
      #@service_host_port = service_host_port
      @service_host_port = 'localhost:9000'
      @http = Net::HTTP.new(@service_host_port)
    end

    # Record the span.
    def record(span)
      @http.post('/spans',
                 Yajl::Encoder.encode(span),
                 {'Content-Type' => 'application/json', :Accept => 'application/json'})
    end

    # Record the annotation.
    def record_annotation(trace_id, id, annotation_data)
      @http.post("/spans/#{trace_id}/#{id}",
                 Yajl::Encoder.encode(annotation_data),
                 {'Content-Type' => 'application/json', :Accept => 'application/json'})
    end
  end
end