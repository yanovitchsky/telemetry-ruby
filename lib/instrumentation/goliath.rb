if defined?(::Goliath)
  module Goliath
    module Rack
      class RequestTracer
        include Goliath::Rack::AsyncMiddleware

        def initialize(app, name)
          @app, @name = app, name
        end

        def call(env)
          trace_id = env[header_hash_name('X-Telemetry-TraceId')]
          span_id = env[header_hash_name('X-Telemetry-SpanId')]
          if trace_id.nil? || span_id.nil?
            span = Telemetry::Span.start_trace(Telemetry.service_name || "#{@name}#{env['PATH_INFO']}", env['REQUEST_PATH'])
          else
            span = Telemetry::Span.start(Telemetry.service_name || "#{@name}#{env['PATH_INFO']}", trace_id, nil, span_id, true, env['REQUEST_PATH'])
          end
          span.add_annotation('ServerReceived')
          super(env, span)
        end

        def post_process(env, status, headers, body, span)
          p "post process ---------------"
          span.add_annotation('ServerSent')
          span.end
          [status, headers, body]
        end

        def header_hash_name(name)
          'HTTP_' + name.upcase.gsub('-', '_')
        end
      end
    end
  end
end