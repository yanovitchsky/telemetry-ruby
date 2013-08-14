module Rack
  class RequestTracer
    def initialize(app, options = {})
      @app, @options = app, options
    end

    def call(env)
      trace_id = env[header_hash_name('X-Telemetry-TraceId')]
      span_id = env[header_hash_name('X-Telemetry-SpanId')]

      if trace_id.nil? || span_id.nil?
        span = Telemetry::Span.start_trace(env['SCRIPT_NAME'] + env['PATH_INFO'])
      else
        span = Telemetry::Span.attach_span(trace_id, span_id)
      end

      span.add_annotation('ServerReceived')
      span.add_annotation('ServiceName', 'unknown rails - update telemetry-ruby to include')
      status, headers, response = @app.call(env)
      span.add_annotation('ServerSent')

      span.end

      [status, headers, response]
    end

    def header_hash_name(name)
      'HTTP_' + name.upcase.gsub('-', '_')
    end
  end
end