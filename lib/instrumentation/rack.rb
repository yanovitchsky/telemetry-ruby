module Rack
  class RequestTracer
    def initialize(app, options = {})
      @app, @options = app, options
    end

    def call(env)
      trace_id = env[header_hash_name('X-Telemetry-TraceId')]
      span_id = env[header_hash_name('X-Telemetry-SpanId')]

      if trace_id.nil? || span_id.nil?
        span = Telemetry::Span.start_trace(Telemetry.service_name || env['SCRIPT_NAME'] + env['PATH_INFO'], env['REQUEST_URI'])
      else
        span = Telemetry::Span.start(Telemetry.service_name || env['SCRIPT_NAME'] + env['PATH_INFO'], trace_id, nil, span_id, true, env['REQUEST_URI'])
      end

      f_ann = span.add_annotation('ServerReceived', env['REQUEST_URI'])
      status, headers, response = @app.call(env)
      s_ann = span.add_annotation('ServerSent', env['REQUEST_URI'])
      s_ann.link_to_annotation(f_ann)
      span.end
      [status, headers, response]
    end

    def header_hash_name(name)
      'HTTP_' + name.upcase.gsub('-', '_')
    end
  end
end