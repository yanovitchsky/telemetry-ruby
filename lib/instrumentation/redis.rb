module Telemetry
  module Instrumentation
    module Redis
      def self.included(base)
        base.class_eval do
          def call_with_telemetry(*args, &block)
            method_name = args[0].is_a?(Array) ? args[0][0] : args[0]
            myargs = args[0].is_a?(Array) ? args[0] : args
            #metrics = "Redis/#{method_name.to_s.upcase}"
            metrics = myargs[0...-1]
            trace_id = Telemetry::SpanContext.new.current_trace_id
            span_id = Telemetry::SpanContext.new.current_span_id
            if trace_id.nil? || span_id.nil?
              span = Telemetry::Span.start_trace(Telemetry.service_name || "Redis", nil)
            else
              span = Telemetry::Span.attach_span(trace_id, span_id)
            end
            f_ann = span.add_annotation('Redis send', metrics)
            result = self.send(:call_without_telemetry, *args)
            s_ann = span.add_annotation('Redis received', metrics)
            s_ann.link_to_annotation(f_ann)
            span.end
            result
          end
        end
      end
    end
  end
end

if defined?(::Redis)
  ::Redis::Client.class_eval do
    include Telemetry::Instrumentation::Redis
    if ::Redis::Client.new.respond_to?(:call)
      alias :call_without_telemetry :call
      alias :call :call_with_telemetry
    else
      alias :call_without_telemetry :raw_call_command
      alias :raw_call_command :call_with_telemetry
    end
  end
end