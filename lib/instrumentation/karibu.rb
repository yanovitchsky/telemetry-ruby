####
# Instrumentation for karibu
# patch execute method for Karibu::Requester
####
module Telemetry
  module Instrumentation
    module Karibu
      module Client
        def self.included(base)
          base.class_eval do
            define_singleton_method("execute_with_telemetry") do |*args|
              klass = args[2]
              meth = args[3]
              trace_id = Telemetry::SpanContext.new.current_trace_id
              span_id = Telemetry::SpanContext.new.current_span_id
              if trace_id.nil? || span_id.nil?
                span = Telemetry::Span.start_trace(Telemetry.service_name || "karibu client")
              else
                span = Telemetry::Span.attach_span(trace_id, span_id)
                args[4] << {:kaributelemetrytraceid => trace_id.to_s, :kaributelemetryspanid => span_id.to_s}
              end
              # payload later
              span.add_annotation('ClientSend', "#{klass}.#{meth}")
              result = self.send("execute_without_telemetry", *args)
              span.add_annotation('ClientReceived', "#{klass}.#{meth}")
              span.end
              result
            end

            class << self
              alias :execute_without_telemetry :execute
              alias :execute :execute_with_telemetry
            end
          end
        end
      end

      module Dispatcher
        def self.included(base)
          base.class_eval do
            define_method("exec_request_with_telemetry") do |*args|
              request = args.first
              klass = Kernel.const_get(request.resource)
              meth = request.method_called.to_sym
              trace_id = Telemetry::SpanContext.new.current_trace_id
              span_id = Telemetry::SpanContext.new.current_span_id
              last_param = request.params.last
              if request.params.last.class == Hash and 
                (last_param.has_key?(:kaributelemetrytraceid) and last_param.has_key?(:kaributelemetryspanid))
                trace_id = request.params.last[:kaributelemetrytraceid]
                span_id = request.params.last[:kaributelemetryspanid]
                request.params.pop
              end
              if trace_id.nil? || span_id.nil?
                span = Telemetry::Span.start_trace(Telemetry.service_name || "Karibu server")
              else
                span = Telemetry::Span.attach_span(trace_id, span_id)
              end
              span.add_annotation('ServerReceived', "#{klass}.#{meth}")
              result = self.send("exec_request_without_telemetry", *args)
              span.add_annotation('ServerSent', "#{klass}.#{meth}")
              span.end
              result
            end
              alias :exec_request_without_telemetry :exec_request
              alias :exec_request :exec_request_with_telemetry
          end
        end
      end
    end
  end
end

if defined?(::Karibu::Client)
  ::Karibu::Client.class_eval do
    puts "including client"
    include Telemetry::Instrumentation::Karibu::Client
  end
end

if defined?(::Karibu::Dispatcher)
  ::Karibu::Dispatcher.class_eval do
    include Telemetry::Instrumentation::Karibu::Dispatcher
  end
end